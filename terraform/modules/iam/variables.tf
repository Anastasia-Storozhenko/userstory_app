variable "secret_arn" {
  description = "The ARN of the database secret in AWS Secrets Manager."
  type        = string
}

variable "project_name" {
  description = "Prefix for IAM resources"
  type        = string
  default     = "userstory"
}