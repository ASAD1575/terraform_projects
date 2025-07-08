variable "cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "aws_instance" {
  description = "value of the AWS instance"
  type        = string
}

variable "instance_type" {
  description = "The type of AWS instance to create"
  type        = string
  
}

variable "instance_key" {
  description = "The key pair name for the instance"
  type        = string
  
}