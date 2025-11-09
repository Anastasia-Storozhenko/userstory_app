output "db_secret_arn" {
  description = "The ARN of the AWS Secrets Manager secret containing DB credentials"
  value       = data.aws_secretsmanager_secret.db_secret.arn
}

output "db_secret_value" {
  description = "JSON with secret value (username, password)"
  value       = data.aws_secretsmanager_secret_version.db_secret_version.secret_string
  sensitive   = true
}

output "datadog_secret_arn" {
  description = "ARN of the existing Datadog secret"
  value       = data.aws_secretsmanager_secret.datadog_api_key.arn
}

output "datadog_api_key_value" {
  description = "Datadog API key value (sensitive)"
  value       = data.aws_secretsmanager_secret_version.datadog_api_key_version.secret_string
  sensitive   = true
}

output "db_username" {
  description = "The generated database username"
  value       = var.db_username
}

output "db_password_initial" {
  description = "The initial randomly generated password (WARNING: Sensitive)"
  value       = random_password.db_password.result
  sensitive   = true # Mark as sensitive data
}