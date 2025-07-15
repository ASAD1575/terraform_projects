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

data "aws_ami" "ubuntu_latest" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID for Ubuntu

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2_security_group"
  description = "Security group for EC2 instances"

  ingress {
    description = "Allow SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}
  ingress {
    description = "Allow HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Genrerate SSH Key Pair for EC2 Instances
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create Key Pair for EC2 Instances
resource "aws_key_pair" "generated_key" {
  key_name   = "terraform_generated_key_1"
  public_key = tls_private_key.ssh_key.public_key_openssh
    tags = {
    Name = "ssh key"
  }
}

# Create Local File to store the private key
resource "local_file" "private_key_pem" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "${path.module}/ec2_key.pem"
  file_permission = "0600"
}


resource "aws_instance" "my_ec2_instance" {
  ami           = data.aws_ami.ubuntu_latest.id
  instance_type = "t3.micro"
  key_name      =  aws_key_pair.generated_key.key_name
  security_groups = [aws_security_group.ec2_sg.name]

  tags = {
    Name = "MyEC2Instance"
  }
  
}
