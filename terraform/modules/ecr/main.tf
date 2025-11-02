# --- 1. ECR Репозиторий для Frontend ---
#resource "aws_ecr_repository" "frontend_repo" {
data "aws_ecr_repository" "frontend_repo" {
  name                 = var.frontend_repo_name
  #image_scanning_configuration {
  #  scan_on_push = true
  #}
  #image_tag_mutability = "IMMUTABLE"
  #lifecycle {
  #  prevent_destroy = true
  #}
}

# --- 2. ECR Репозиторий для Backend ---
#resource "aws_ecr_repository" "backend_repo" {
data "aws_ecr_repository" "backend_repo" {
  name                 = var.backend_repo_name
  #image_scanning_configuration {
  #  scan_on_push = true
  #}
  #image_tag_mutability = "IMMUTABLE"
  #lifecycle {
  #  prevent_destroy = true
  #}
}

# --- 3. ECR Репозиторий для Database ---
#resource "aws_ecr_repository" "database_repo" {
data "aws_ecr_repository" "database_repo" {
  name = var.database_repo_name
  #image_scanning_configuration {
  #  scan_on_push = true
  #}
  #image_tag_mutability = "IMMUTABLE"
  #lifecycle {
  #  prevent_destroy = true
  #}
}