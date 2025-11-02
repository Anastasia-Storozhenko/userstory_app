output "frontend_ecr_uri" {
  description = "URI для пуша/пулла Frontend Docker образа"
  value       = data.aws_ecr_repository.frontend_repo.repository_url
}

output "backend_ecr_uri" {
  description = "URI для пуша/пулла Backend Docker образа"
  value       = data.aws_ecr_repository.backend_repo.repository_url
}

output "database_ecr_uri" {
  description = "URI для пуша/пулла Backend Docker образа"
  value       = data.aws_ecr_repository.database_repo.repository_url
}

output "database_repo_name" {
  description = "Name for the database ECR repository"
  value     = "userstory-database-repo"
}
