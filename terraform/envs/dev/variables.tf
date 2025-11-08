# Global environment variables
variable "env_name" {
  type    = string
  default = "dev"
}

variable "project_prefix" {
  type    = string
  default = "userstory"
}

# Variables to access
variable "my_ip_for_ssh" {
  description = "Your workstation IP CIDR for SSH access (e.g., 188.163.83.183/32)"
  type        = string
  default     = "0.0.0.0/0" # My IP address or the entire Internet
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
