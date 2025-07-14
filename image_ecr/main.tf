terraform {
    required_providers {
        aws = {
        source  = "hashicorp/aws"
        version = "~> 3.0"
        }
    }
    
}

provider "aws" {
  region = "eu-north-1"
}

resource "aws_ecr_repository" "my-app-repo" {
  name                 = "my-ecr-repository"
  image_tag_mutability = "MUTABLE"
  tags = {
    Name = "my-ecr-repo"
  }
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "my_ecr_lifecycle_policy" {
  repository = aws_ecr_repository.my-app-repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 30 days"
        selection    = {
          tagStatus = "untagged"
          countType = "sinceImagePushed"
          countUnit = "days"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

output "repo_url" {
  value = aws_ecr_repository.my-app-repo.repository_url
  
}