variable "frontend_repo_name" {
  description = "Name for the frontend ECR repository"
  type        = string
  default     = "userstory-frontend-repo"
}

variable "backend_repo_name" {
  description = "Name for the backend ECR repository"
  type        = string
  default     = "userstory-backend-repo"
}

variable "database_repo_name" {
  description = "URI для пуша/пулла Database Docker образа"
  default     = "userstory-database-repo"
}
