# Pare-feu du Load Balancer (Accepte le trafic Internet)
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Autorise le trafic HTTP depuis Internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Pare-feu des conteneurs ECS Fargate (Nginx & PHP)
resource "aws_security_group" "ecs_sg" {
  name        = "${var.project_name}-ecs-sg"
  description = "Autorise le trafic depuis ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  # Autorise la communication interne entre le conteneur Nginx et PHP sur le port 9000
  ingress {
    from_port = 9000
    to_port   = 9000
    protocol  = "tcp"
    self      = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Pare-feu pour la Base de données et le Stockage (RDS & EFS)
resource "aws_security_group" "data_sg" {
  name        = "${var.project_name}-data-sg"
  description = "Autorise l acces depuis ECS uniquement"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306 # Port MariaDB
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }
  ingress {
    from_port       = 2049 # Port NFS/EFS
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

resource "aws_db_instance" "moodle_db" {
  identifier             = "${var.project_name}-db-v3"
  engine                 = "mariadb"
  engine_version         = "10.11"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "moodledb"
  username               = "root"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.data_sg.id]
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-db-backup"
  multi_az               = false
}

resource "aws_efs_file_system" "moodle_data" {
  creation_token = "${var.project_name}-efs"
  tags           = { Name = "${var.project_name}-efs" }
}

# Points de montage EFS dans vos deux sous-réseaux privés
resource "aws_efs_mount_target" "efs_mt_1" {
  file_system_id  = aws_efs_file_system.moodle_data.id
  subnet_id       = aws_subnet.private_1.id
  security_groups = [aws_security_group.data_sg.id]
}

resource "aws_efs_mount_target" "efs_mt_2" {
  file_system_id  = aws_efs_file_system.moodle_data.id
  subnet_id       = aws_subnet.private_2.id
  security_groups = [aws_security_group.data_sg.id]
}

# Point d'accès EFS pour forcer les permissions www-data (UID 33)
resource "aws_efs_access_point" "moodle_ap" {
  file_system_id = aws_efs_file_system.moodle_data.id
  
  posix_user {
    gid = 33
    uid = 33
  }
  
  root_directory {
    path = "/moodledata"
    creation_info {
      owner_gid   = 33
      owner_uid   = 33
      permissions = "0777"
    }
  }
}

#  Création du coffre-fort dans Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}-db-password"
  recovery_window_in_days = 0 # Permet une suppression immédiate lors d'un terraform destroy
}

#  Stockage de la valeur du mot de passe
resource "aws_secretsmanager_secret_version" "db_password_val" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}