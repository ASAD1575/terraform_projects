output "repo_url" {
  value = aws_ecr_repository.my-app-repo.repository_url
  
}

output "ec2_public_ip" {
  value = aws_instance.my_ec2_instance.public_ip
  
}

output "ec2_id" {
  value = aws_instance.my_ec2_instance
}