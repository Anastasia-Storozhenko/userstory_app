variable "key_pair_name" {
  description = "Key pair name."
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID."
  type        = string
}

variable "public_subnet_id" {
  description = "ID of the public subnet for the Frontend/Bastion."
  type        = string
}

variable "private_subnet_id" {
  description = "ID of the private subnet for Backend and Database."
  type        = string
}

variable "sg_ids" {
  description = "Map of Security Group IDs for different instances."
  type = object({
    bastion_lb = string
    frontend   = string
    backend    = string
    database   = string
  })
}

variable "instance_profile_name" {
  description = "The name of the IAM Instance Profile to attach to the EC2 instances."
  type        = string
}

# --- Variables for user_data (containers) ---
variable "aws_region" {
  description = "The AWS region."
  type        = string
}

variable "ecr_frontend_url" {
  description = "ECR URI for the Frontend Docker image."
  type        = string
}

variable "ecr_backend_url" {
  description = "ECR URI for the Backend Docker image."
  type        = string
}

variable "ecr_database_url" {
  description = "Full URI of the database Docker image in ECR"
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials."
  type        = string
}

variable "datadog_secret_arn" {
  type        = string
  description = "ARN of the Datadog API key secret"
}
