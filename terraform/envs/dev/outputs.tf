output "bastion_public_ip" {
  description = "The public IP address of the Bastion/LB instance."
  value       = module.ec2.bastion_public_ip
}
