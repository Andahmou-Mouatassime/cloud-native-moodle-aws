# Lecture seule des dépôts ECR existants (ne seront jamais détruits)
data "aws_ecr_repository" "nginx" {
  name = "${var.project_name}-nginx"
}

data "aws_ecr_repository" "php" {
  name = "${var.project_name}-php"
}

# 2. Le Cluster ECS
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

# 3. L'Application Load Balancer (ALB)
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

# 4. Le Groupe Cible (Target Group) pour acheminer le trafic vers Nginx
resource "aws_lb_target_group" "nginx" {
  name        = "${var.project_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # Indispensable pour AWS Fargate

  health_check {
    path                = "/"
    matcher             = "200-399" # Moodle effectue souvent des redirections 303
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# 5. L'écouteur (Listener) sur le port 80
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx.arn
  }
}

# 6. Outputs (Pour récupérer facilement les adresses générées)
output "alb_dns_name" {
  description = "L'adresse URL publique de votre plateforme Moodle"
  value       = aws_lb.main.dns_name
}

output "ecr_nginx_url" {
  value = data.aws_ecr_repository.nginx.repository_url
}

output "ecr_php_url" {
  value = data.aws_ecr_repository.php.repository_url
}