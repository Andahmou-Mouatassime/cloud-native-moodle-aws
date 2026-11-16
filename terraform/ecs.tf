# 1. Rôle IAM (Donne le droit à ECS de télécharger vos images et d'écrire des logs)
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 2. Groupe de logs CloudWatch (Pour surveiller Nginx et PHP depuis AWS)
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}

# 3. La Task Definition (Le "docker-compose" version AWS)
resource "aws_ecs_task_definition" "moodle" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024" # 1 vCPU dédié
  memory                   = "2048" # 2 Go de RAM
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  # Connexion au disque dur réseau (EFS)
  volume {
    name = "moodle-efs-storage"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.moodle_data.id
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.moodle_ap.id
        iam             = "DISABLED"
      }
    }
  }

  # Définition des 2 conteneurs (Nginx + PHP) fonctionnant ensemble
  container_definitions = jsonencode([
    {
      name      = "php"
      image     = "${data.aws_ecr_repository.php.repository_url}:latest"
      essential = true
      portMappings = [{ containerPort = 9000, protocol = "tcp" }]
      
      # Variables d'environnement non sensibles
      environment = [
        { name = "DB_HOST", value = aws_db_instance.moodle_db.address },
        { name = "DB_NAME", value = "moodledb" },
        { name = "DB_USER", value = "root" },
        { name = "WWW_ROOT", value = "http://${aws_lb.main.dns_name}" }
      ]

      # Injection sécurisée du mot de passe depuis AWS Secrets Manager
      secrets = [
        {
          name      = "DB_PASS"
          valueFrom = aws_secretsmanager_secret.db_password.arn
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "moodle-efs-storage"
          containerPath = "/var/www/moodledata"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "php"
        }
      }
    },
    {
      name      = "nginx"
      image = "${data.aws_ecr_repository.nginx.repository_url}:latest"
      essential = true
      portMappings = [{ containerPort = 80, protocol = "tcp" }]
      mountPoints = [
        {
          sourceVolume  = "moodle-efs-storage"
          containerPath = "/var/www/moodledata"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "nginx"
        }
      }
    }
  ])
}

# 4. Le Service ECS (Assure que l'application tourne H24)
resource "aws_ecs_service" "moodle" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.moodle.arn
  launch_type     = "FARGATE"
  desired_count   = 1 # Nombre de tâches (à passer à 2 ou plus tard pour la Haute Disponibilité)

  # Placement ultra-sécurisé dans les sous-réseaux privés
  network_configuration {
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false 
  }

  # Connexion au Load Balancer
  load_balancer {
    target_group_arn = aws_lb_target_group.nginx.arn
    container_name   = "nginx"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]
}


resource "aws_iam_role_policy" "ecs_secrets_policy" {
  name = "${var.project_name}-ecs-secrets-policy"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [aws_secretsmanager_secret.db_password.arn]
      }
    ]
  })
}