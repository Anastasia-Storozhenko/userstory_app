variable "vpc_id" {
  description = "ID of the VPC to which the ACL is attached"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for NACL binding"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "CIDR block VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "project_name" {
  description = "Project name for tags"
  type        = string
}
