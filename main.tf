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

resource "aws_ecr_repository" "myapprepo" {
  name                 = "myecrrepository"
  image_tag_mutability = "MUTABLE"
  tags = {
    Name = "my-ecr-repo"
  }
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "my_ecr_lifecycle_policy" {
  repository = aws_ecr_repository.myapprepo.name

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

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  instance_tenancy = "default"
  tags = {
    Name = "my_vpc"
  }
  
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.0/24"
  count             = 2
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet_${count.index + 1}"
  }
  
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2_security_group"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.my_vpc.id
  tags = {
    Name = "ec2_security_group"
  }

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
resource "aws_key_pair" "key_generated" {
  key_name   = "terraform_generated_key_1"
  public_key = tls_private_key.ssh_key.public_key_openssh
    tags = {
    Name = "ssh key"
  }
}

# Create Local File to store the private key
resource "local_file" "private_key_pem" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "${path.module}/ec2key.pem"
  file_permission = "0600"
}


resource "aws_instance" "my_ec2_instance" {
  ami           = data.aws_ami.ubuntu_latest.id
  instance_type = "t3.micro"
  key_name      =  aws_key_pair.key_generated.key_name
  security_groups = [aws_security_group.ec2_sg.name]
  subnet_id     = aws_subnet.public_subnet[0].id
  associate_public_ip_address = true

  tags = {
    Name = "MyEC2Instance"
  }
  
}
