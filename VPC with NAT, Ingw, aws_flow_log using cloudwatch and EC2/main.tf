# Create a VPC in Stockholm region
resource "aws_vpc" "stockholm_vpc" {
  cidr_block = var.cidr_block
  enable_dns_support = true
  tags = {
    Name = "Stockholm VPC"  
    }
}

# Create Public Subnet in Stockholm VPC
resource "aws_subnet" "Public_subnet" {
    vpc_id = aws_vpc.stockholm_vpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "eu-north-1a"
    map_public_ip_on_launch = true
    tags = {
        Name = "Public Subnet"
    }
}

# Create Private Subnet in Stockholm VPC
resource "aws_subnet" "Private_subnet" {
    vpc_id = aws_vpc.stockholm_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-north-1a"
    map_public_ip_on_launch = true
    tags = {
        Name = "Private Subnet"
    }
}

# Create Route Table
resource "aws_route_table" "stockholm_RT" {
    vpc_id = aws_vpc.stockholm_vpc.id
    tags = {
        Name = "Stockholm Public Route Table"
    }
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.stockholm_igw.id
    }
    route {
        cidr_block = "10.0.1.0/24"
        nat_gateway_id = aws_nat_gateway.stockholm_nat.id
    }
  
}

# Route Table Association for Public Subnet
resource "aws_route_table_association" "Public_subnet_association" {
    subnet_id = aws_subnet.Public_subnet.id
    route_table_id = aws_route_table.stockholm_RT.id
}

# Route Table Association for Private Subnet
resource "aws_route_table_association" "Private_subnet_association" {
    subnet_id = aws_subnet.Private_subnet.id
    route_table_id = aws_route_table.stockholm_RT.id
}

# Create Internet Gateway
resource "aws_internet_gateway" "stockholm_igw" {
    vpc_id = aws_vpc.stockholm_vpc.id
    tags = {
        Name = "Stockholm Internet Gateway"
    }
}

# Create NAT Gateway
resource "aws_nat_gateway" "stockholm_nat" {
    allocation_id = aws_eip.stockholm_eip.id
    subnet_id = aws_subnet.Public_subnet.id
    tags = {
        Name = "Stockholm NAT Gateway" 
    }
}

# Create Elastic IP for NAT Gateway
resource "aws_eip" "stockholm_eip" {
    tags = {
        Name = "Stockholm NAT EIP"
    }
}

# Create Security Group for Stockholm VPC
resource "aws_security_group" "stockholm_sg" {
  name        = "Stockholm Security Group"
  description = "Security group for Stockholm VPC"
  vpc_id     = aws_vpc.stockholm_vpc.id
    tags = {
        Name = "Stockholm Security Group"
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
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }
  
}

# Create EC2 Instance in Stockholm VPC
resource "aws_instance" "stockholm_instance" {
  ami           = var.aws_instance # Replace with a valid AMI ID for your region
  instance_type = var.instance_type
  subnet_id     = aws_subnet.Public_subnet.id
  vpc_security_group_ids = [aws_security_group.stockholm_sg.id]
  key_name = var.instance_key
  associate_public_ip_address = true  
    tags = {
    Name = "Stockholm EC2 Instance"
  } 
}

# Create CloudWatch Log Group for Flow Logs
resource "aws_cloudwatch_log_group" "stockholm_log_group" {
  name = "StockholmVPCFlowLogs"
  retention_in_days = 7
}

# Create Flow Logs for Stockholm VPC
resource "aws_flow_log" "stockholm_flow_log" {
  vpc_id       = aws_vpc.stockholm_vpc.id
  traffic_type = "ALL"
  log_destination = aws_cloudwatch_log_group.stockholm_log_group.arn
  iam_role_arn = aws_iam_role.flow_log_role.arn
}

# Create IAM Role for Flow Logs
resource "aws_iam_role" "flow_log_role" {
  name = "StockholmVPCFlowLogRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

# Create Flow Log for EC2 Instance
resource "aws_flow_log" "ec2_flow_log" {
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.stockholm_log_group.arn
  iam_role_arn         = aws_iam_role.flow_log_role.arn
  traffic_type         = "ALL"
  eni_id               = aws_instance.stockholm_instance.primary_network_interface_id
}

# Attach IAM Policy to Flow Log Role
resource "aws_iam_role_policy" "flowlog_policy" {
  name = "ec2-flowlog-policy"
  role = aws_iam_role.flow_log_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "logs:PutLogEvents",
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

