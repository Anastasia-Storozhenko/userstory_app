terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "userstory-terraform-state"
    key            = "dev/infrastructure.tfstate" # Важно: путь привязан к окружению!
    region         = "us-east-1"
    dynamodb_table = "userstory-terraform-locks"
    # use_lockfile   = true
    encrypt = true
  }
}

provider "aws" {
  region = "us-east-1"
}