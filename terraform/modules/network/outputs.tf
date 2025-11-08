output "network_acl_id" {
  description = "ID созданного NACL"
  value       = aws_network_acl.main.id
}
