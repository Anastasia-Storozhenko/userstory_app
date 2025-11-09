data "aws_region" "current" {}

# --- 1. VPC Module
module "vpc" {
  source = "../../modules/vpc"
  # Pass variables (if they differ from the default in the module)
  project_name = var.project_prefix
  aws_region   = data.aws_region.current.name
  vpc_cidr     = var.vpc_cidr
}

# --- 2. Security Groups Module (Must be first because SG needs VPC Endpoints)
module "security_groups" {
  source       = "../../modules/sg"
  vpc_id       = module.vpc.vpc_id # ID VPC from VPC module
  my_ip_cidr   = var.my_ip_for_ssh
  # Default ports: Backend 8080, DB 3306 - can be overridden here
  vpc_cidr     = var.vpc_cidr
  project_name = var.project_prefix
}

# --- 3. Network Module
module "network" {
  source       = "../../modules/network"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = [module.vpc.public_subnet_id, module.vpc.private_subnet_id]
  vpc_cidr     = "10.0.0.0/16"
  project_name = "userstory"
}

# --- 4. ECR Module
module "ecr" {
  source = "../../modules/ecr"
}

# --- 5. Secrets Manager Module
module "secrets" {
  source      = "../../modules/secrets"
  secret_name = "${var.project_prefix}-${var.env_name}-db-secret-v7"
}

# --- 6. IAM Module (for EC2 permissions)
module "iam" {
  source       = "../../modules/iam"
  project_name = var.project_prefix
  secret_arn   = module.secrets.db_secret_arn # Secret's ARN from the Secrets Manager module
}

# --- 7. EC2 Instances Module
module "ec2" {
  source            = "../../modules/ec2"
  vpc_id            = module.vpc.vpc_id
  public_subnet_id  = module.vpc.public_subnet_id
  private_subnet_id = module.vpc.private_subnet_id

  # Security Groups
  sg_ids = {
    bastion_lb = module.security_groups.sg_bastion_lb_id
    frontend   = module.security_groups.sg_frontend_id
    backend    = module.security_groups.sg_backend_id
    database   = module.security_groups.sg_database_id
  }
  instance_profile_name = module.iam.ec2_instance_profile_name
  key_pair_name         = "userstory-deployer-key"

  # Parameters for automation (user_data):
  aws_region       = data.aws_region.current.name
  ecr_frontend_url = module.ecr.frontend_ecr_uri
  ecr_backend_url  = module.ecr.backend_ecr_uri
  db_secret_arn    = "arn:aws:secretsmanager:us-east-1:182000022338:secret:userstory-dev-db-secret-v7-ETNfQm"
  ecr_database_url = module.ecr.database_ecr_uri
  datadog_secret_arn = module.secrets.datadog_secret_arn

  # Dependencies
  depends_on = [
    module.iam,
    module.security_groups,
    module.secrets
  ]
}

# --- 8. Interface Endpoints (used SG for Endpoints)
# --- 8.1. Endpoint for Secrets Manager (Interface)
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc.private_subnet_id]              # Binding to a private subnet
  security_group_ids  = [module.security_groups.vpc_endpoint_sg_id] # SG is available because the sg module has already been executed
  private_dns_enabled = true
}

# --- 8.2. Endpoint for ECR DKR (Interface) - for download Docker images
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc.private_subnet_id]
  security_group_ids  = [module.security_groups.vpc_endpoint_sg_id]
  private_dns_enabled = true
}

# --- 8.3. Endpoint for ECR API (Interface) - for manage ECR
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc.private_subnet_id]
  security_group_ids  = [module.security_groups.vpc_endpoint_sg_id]
  private_dns_enabled = true
}

# --- 8.4. Endpoint for SSM (Interface) - for secure access to VM (Systems Manager)
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc.private_subnet_id]
  security_group_ids  = [module.security_groups.vpc_endpoint_sg_id]
  private_dns_enabled = true
}

# --- 8.5. Endpoint for EC2 Messages (Interface) - part SSM
resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc.private_subnet_id]
  security_group_ids  = [module.security_groups.vpc_endpoint_sg_id]
  private_dns_enabled = true
}

# --- 8.6. Endpoint for SSM Messages (Interface) - part SSM
resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc.private_subnet_id]
  security_group_ids  = [module.security_groups.vpc_endpoint_sg_id]
  private_dns_enabled = true
}

# --- 8.7. Endpoint for S3 (Gateway) - for access to state and ECR
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [module.vpc.private_route_table_id] # Binding to a private routing table
}
