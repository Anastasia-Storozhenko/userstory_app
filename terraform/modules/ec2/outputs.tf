output "key_pair_name" {
  description = "The name of the key pair created for SSH access."
  value       = aws_key_pair.deployer.key_name
}

output "bastion_public_ip" {
  description = "The public IP address of the Frontend/LB instance."
  value       = aws_instance.bastion_instance.public_ip
}

output "db_private_ip" {
  description = "The private IP address of the Database instance. Used by Backend."
  value       = aws_instance.database_instance.private_ip
}

output "frontend_private_ip" {
  description = "The private IP address of the Frontend instance."
  value       = aws_instance.frontend_instance.private_ip
}

output "db_endpoint" {
  value = aws_instance.database_instance.private_ip
}