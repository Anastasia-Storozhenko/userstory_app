# --- 1. ECR for Frontend ---
data "aws_ecr_repository" "frontend_repo" {
  name = var.frontend_repo_name
}

# --- 2. ECR for Backend ---
data "aws_ecr_repository" "backend_repo" {
  name = var.backend_repo_name
}

# --- 3. ECR for Database ---
data "aws_ecr_repository" "database_repo" {
  name = var.database_repo_name
}
