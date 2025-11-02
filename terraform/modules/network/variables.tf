variable "vpc_id" {
  description = "ID VPC, к которой привязывается ACL"
  type        = string
}

variable "subnet_ids" {
  description = "Список subnet IDs для привязки NACL"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "CIDR блок VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "project_name" {
  description = "Имя проекта для тегов"
  type        = string
}
