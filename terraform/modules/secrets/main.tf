# Use a random provider to generate a complex password
resource "random_password" "db_password" {
  length           = var.db_password_length
  special          = true
  override_special = "!#$%&*()_-+="
  upper            = true
  lower            = true
  numeric          = true
}

# Get the secret from AWS Secrets Manager
data "aws_secretsmanager_secret" "db_secret" {
  name = var.secret_name
}

# Write the generated credentials to a secret in JSON format
data "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = data.aws_secretsmanager_secret.db_secret.id
}

# Get tehe API key from AWS Secrets Manager ---
data "aws_secretsmanager_secret" "datadog_api_key" {
  name = "userstory-datadog-secret"
}

# Write the generated credentials to a secret in JSON format
data "aws_secretsmanager_secret_version" "datadog_api_key_version" {
  secret_id = data.aws_secretsmanager_secret.datadog_api_key.id
}
