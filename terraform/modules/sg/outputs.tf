output "sg_bastion_lb_id" {
  description = "The ID of the Bastion/Load Balancer Security Group"
  value       = aws_security_group.bastion_lb.id
}

output "sg_frontend_id" {
  description = "The ID of the Frontend Security Group"
  value       = aws_security_group.frontend.id
}

output "sg_backend_id" {
  description = "The ID of the Backend Security Group"
  value       = aws_security_group.backend.id
}

output "sg_database_id" {
  description = "The ID of the Database Security Group"
  value       = aws_security_group.database.id
}

output "vpc_endpoint_sg_id" {
  description = "The ID of the Security Group for VPC Endpoints"
  value       = aws_security_group.sg_vpc_endpoint.id
}

output "database_security_group_id" {
  description = "The ID of the Security Group attached to the Database instance/RDS."
  value       = aws_security_group.database.id 
}

output "bastion_lb_security_group_id" {
  description = "The ID of the Security Group attached to the Bastion/LB instance."
  value       = aws_security_group.bastion_lb.id
}