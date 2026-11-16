terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Assurez-vous d'avoir configuré vos credentials AWS (aws configure) dans votre terminal
provider "aws" {
  region = var.aws_region
}