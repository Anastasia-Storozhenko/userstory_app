terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "userstory-terraform-state"
    key            = "dev/infrastructure.tfstate" # Important: the path is tied to the environment!
    region         = "us-east-1"
    dynamodb_table = "userstory-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}
