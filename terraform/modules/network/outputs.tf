output "network_acl_id" {
  description = "ID of the created NACL"
  value       = aws_network_acl.main.id
}
