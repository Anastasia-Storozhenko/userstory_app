variable "vpc_id" {
  description = "The VPC ID to associate with the security groups"
  type        = string
}

variable "my_ip_cidr" {
  description = "Your workstation IP CIDR for SSH access (e.g., 188.163.83.183/32)"
  type        = string
}

variable "backend_port" {
  description = "The port the Backend service listens on"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "The port the Database service listens on (e.g., Postgres)"
  type        = number
  default     = 3306
}

variable "vpc_cidr" {
  description = "The CIDR block of the main VPC (e.g., 10.0.0.0/16)"
  type        = string
}
