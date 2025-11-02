output "ec2_instance_profile_name" {
  description = "The ARN of the IAM Instance Profile to attach to EC2 instances."
  value       = aws_iam_instance_profile.ec2_profile.name
}