# --- 0. SSH Key Pair ---
# Этот ресурс использует userstory_key.pub из корневого каталога
resource "aws_key_pair" "deployer" {
  key_name   = "userstory-deployer-key" 
  # Путь к публичному ключу относительно корневого каталога проекта
  public_key = file("../../userstory_key.pub") 
}

# --- DATA: Получаем актуальный AMI Amazon Linux 2 (для стабильности Docker) ---
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

# --- 1. Database EC2 Instance (Приватная подсеть) ---
resource "aws_instance" "database_instance" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.micro"
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [var.sg_ids.database]
  associate_public_ip_address = false
  # Привязываем IAM Role для доступа к Secrets Manager и ECR (для DB)
  iam_instance_profile        = var.instance_profile_name
  
  # DB запускается в контейнере MariaDB
  user_data = templatefile("${path.module}/user_data/database.sh", {
    AWS_REGION        = var.aws_region
    DB_SECRET_ARN     = var.db_secret_arn
    DB_IMAGE_URI      = var.ecr_database_url
    DB_NAME           = "userstory"
    DB_USER           = "userstory_admin"
    ACCOUNT_ID        = "182000022338"
  })

  user_data_replace_on_change = true

  tags = {
    Name    = "Database-VM"
    Project = "UserStory"
  }
}

# --- 2. Backend EC2 Instance (Приватная подсеть) ---
resource "aws_instance" "backend_instance" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.micro"
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [var.sg_ids.backend]
  associate_public_ip_address = false
  # Привязываем IAM Role для доступа к Secrets Manager и ECR (для Backend)
  iam_instance_profile        = var.instance_profile_name

  # Backend запускается в контейнере
  user_data = templatefile("${path.module}/user_data/backend.sh", {
    AWS_REGION      = var.aws_region
    ECR_BACKEND_URL = var.ecr_backend_url
    DB_SECRET_ARN   = var.db_secret_arn
    # ИСПОЛЬЗУЕМ ПРИВАТНЫЙ IP АДРЕС БД, переданный из envs/dev/main.tf
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

# --- 3. Frontend/LB EC2 Instance (Публичная подсеть) ---
resource "aws_instance" "frontend_instance" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.micro"
  subnet_id                   = var.private_subnet_id
  # Используем SG Бастиона/LB
  vpc_security_group_ids      = [var.sg_ids.frontend] 
  associate_public_ip_address = false
  # Привязываем IAM Role для доступа к ECR (для Frontend)
  iam_instance_profile        = var.instance_profile_name

  # Frontend запускается в контейнере
  user_data = templatefile("${path.module}/user_data/frontend.sh", {
    AWS_REGION          = var.aws_region
    ECR_FRONTEND_URL    = var.ecr_frontend_url
    # Frontend не нуждается в Secret ARN, так как он не обращается к БД
    DB_SECRET_ARN       = var.db_secret_arn
    BACKEND_PRIVATE_IP  = aws_instance.backend_instance.private_ip
  })

  user_data_replace_on_change = true

  tags = {
    Name    = "Frontend-LB-VM"
    Project = "UserStory"
  }
}

# --- 0. Bastion EC2 Instance (Публичная подсеть) ---
resource "aws_instance" "bastion_instance" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro" 
  key_name      = var.key_pair_name # Имя ключа, переданное в модуль
  
  subnet_id = var.public_subnet_id 

  vpc_security_group_ids = [
    var.sg_ids["bastion_lb"]
  ]

  # Обязательно назначаем публичный IP, так как он служит шлюзом
  associate_public_ip_address = true 
  
  # Профиль IAM для доступа к ECR и Secrets Manager (и, возможно, SSM)
  iam_instance_profile = var.instance_profile_name 

  # User Data Script для настройки Nginx Reverse Proxy
  user_data = templatefile("${path.module}/user_data/bastion.sh", {
    # *** КЛЮЧЕВОЙ МОМЕНТ: Передаем приватный IP Frontend-инстанса ***
    FRONTEND_IP = aws_instance.frontend_instance.private_ip 
    BACKEND_IP  = aws_instance.backend_instance.private_ip
  })

  user_data_replace_on_change = true

  lifecycle {
    replace_triggered_by = [
      aws_instance.frontend_instance.private_ip,
      aws_instance.backend_instance.private_ip
    ]
  }

  tags = {
    Name    = "Bastion-VM"
    Project = "UserStory"
  }
}