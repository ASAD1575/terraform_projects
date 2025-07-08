# output for VPC ID
output "vpc_id" {
  value = aws_vpc.stockholm_vpc.id
  
}

# output for Public IP of the EC2 instance
output "instance_public_ip" {
  value = aws_instance.stockholm_instance.public_ip
  
}
