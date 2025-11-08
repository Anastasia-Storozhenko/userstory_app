output "frontend_ecr_uri" {
  description = "URI for pushing/pulling Frontend Docker images"
  value       = data.aws_ecr_repository.frontend_repo.repository_url
}

output "backend_ecr_uri" {
  description = "URI for pushing/pulling Backend Docker images"
  value       = data.aws_ecr_repository.backend_repo.repository_url
}

output "database_ecr_uri" {
  description = "URI for pushing/pulling Database Docker images"
  value       = data.aws_ecr_repository.database_repo.repository_url
}

output "database_repo_name" {
  description = "Name for the database ECR repository"
  value       = "userstory-database-repo"
}
