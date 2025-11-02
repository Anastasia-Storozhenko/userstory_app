variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "The CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "The CIDR block for the private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "project_name" {
  description = "Prefix for resources"
  type        = string
  default     = "UserStory"
}

variable "aws_region" {
  description = "AWS region where resources are deployed (e.g., us-east-1)"
  type        = string
}

variable "sg_vpc_endpoint_id" {
  description = "The ID of the Security Group to attach to VPC Interface Endpoints"
  type        = string
  default     = null
}