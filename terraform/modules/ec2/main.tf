# --- 1. SSH Key Pair (uses userstory_key.pub from the root directory)
resource "aws_key_pair" "deployer" {
  key_name   = "userstory-deployer-key" 
  public_key = file("../../userstory_key.pub") # The path to the public key relative to the project root directory
}

# --- 2. Actual AMI Amazon Linux 2 (for Docker stability) ---
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- 3. Database EC2 Instance (Private subnet) ---
resource "aws_instance" "database_instance" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.micro"
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [var.sg_ids.database]
  associate_public_ip_address = false
  iam_instance_profile        = var.instance_profile_name # Bind IAM Role for access to Secrets Manager
  
  # Database runs in a container
  user_data = templatefile("${path.module}/user_data/database.sh", {
    AWS_REGION        = var.aws_region
    DB_SECRET_ARN     = var.db_secret_arn
    DB_IMAGE_URI      = var.ecr_database_url
    DB_NAME           = "userstory"
    DB_USERNAME       = "userstory_admin"
    ACCOUNT_ID        = "182000022338"
  })

  user_data_replace_on_change = true

  tags = {
    Name    = "Database-VM"
    Project = "UserStory"
  }
}

# --- 4. Backend EC2 Instance (Private subnet) ---
resource "aws_instance" "backend_instance" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.micro"
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [var.sg_ids.backend]
  associate_public_ip_address = false
  iam_instance_profile        = var.instance_profile_name

  # Backend runs in container
  user_data = templatefile("${path.module}/user_data/backend.sh", {
    AWS_REGION      = var.aws_region
    ECR_BACKEND_URL = var.ecr_backend_url
    DB_SECRET_ARN   = var.db_secret_arn
    DB_PRIVATE_IP   = aws_instance.database_instance.private_ip
    DB_HOST         = aws_instance.database_instance.private_ip
    DB_IMAGE_URI    = var.ecr_database_url
    DB_USERNAME     = "userstory_admin"
    DB_PASSWORD     = "devuser"
    ACCOUNT_ID      = "182000022338"
  })

  user_data_replace_on_change = true

  tags = {
    Name    = "Backend-VM"
    Project = "UserStory"
  }
}

# --- 5. Frontend/LB EC2 Instance (Private subnet) ---
resource "aws_instance" "frontend_instance" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.micro"
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [var.sg_ids.frontend] # Uses SG Bastion/LB
  associate_public_ip_address = false
  iam_instance_profile        = var.instance_profile_name

  # Frontend runs in container
  user_data = templatefile("${path.module}/user_data/frontend.sh", {
    AWS_REGION          = var.aws_region
    ECR_FRONTEND_URL    = var.ecr_frontend_url
    DB_SECRET_ARN       = var.db_secret_arn
    BACKEND_PRIVATE_IP  = aws_instance.backend_instance.private_ip
  })

  user_data_replace_on_change = true

  tags = {
    Name    = "Frontend-LB-VM"
    Project = "UserStory"
  }
}

# --- 6. Bastion EC2 Instance (Public subnet) ---
resource "aws_instance" "bastion_instance" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.micro" 
  subnet_id                   = var.public_subnet_id 
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [var.sg_ids["bastion_lb"]]
  associate_public_ip_address = true # Assign a public IP, as it serves as a gateway
  iam_instance_profile        = var.instance_profile_name

  # User Data Script for setting up Nginx Reverse Proxy
  user_data = templatefile("${path.module}/user_data/bastion.sh", {
    FRONTEND_IP = aws_instance.frontend_instance.private_ip 
    BACKEND_IP  = aws_instance.backend_instance.private_ip
  })

  user_data_replace_on_change = true

  tags = {
    Name    = "Bastion-VM"
    Project = "UserStory"
  }

  lifecycle {
    replace_triggered_by = [
      aws_instance.frontend_instance.private_ip,
      aws_instance.backend_instance.private_ip
    ]
  }
}
