# Глобальные переменные окружения
variable "env_name" {
  type    = string
  default = "dev"
}

variable "project_prefix" {
  type    = string
  default = "userstory"
}

# Переменные для доступа
variable "my_ip_for_ssh" {
  description = "Your workstation IP CIDR for SSH access (e.g., 188.163.83.183/32)"
  type        = string
  # default     = "188.163.82.1/32" # Мой IP адресс
  default = "0.0.0.0/0" # Мой IP адресс
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "private_key_path" {
  description = "The file path to the private SSH key (.pem) required for the remote-exec provisioner to connect to the Bastion."
  type        = string
  default     = "../../userstory_key"
}

variable "backend_port" {
  description = "The port on which the backend application listens."
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "The port on which the database listens (MySQL/MariaDB)."
  type        = number
  default     = 3306
}

#variable "database_image_uri" {
#  description = "Full URI of the database Docker image in ECR"
#  type        = string
#}