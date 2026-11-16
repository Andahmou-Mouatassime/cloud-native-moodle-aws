variable "aws_region" {
  description = "Région AWS de déploiement"
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nom du projet pour les tags"
  default     = "moodle-pfa"
}

variable "vpc_cidr" {
  description = "Plage d'adresses IP du VPC"
  default     = "10.0.0.0/16"
}

variable "db_password" {
  description = "Mot de passe de la base de données MariaDB"
  type        = string
  sensitive   = true
}