# --- 1. DATA SOURCE: Получаем список AZ, чтобы выбрать первую (для одной зоны) ---
data "aws_availability_zones" "available" {
  state = "available"
}

# --- 1. Основная Сеть VPC ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-VPC"
  }
}

# --- 2. Internet Gateway (IGW) ---
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-IGW"
  }
}

# --- 3. Подсети (Subnets) в ОДНОЙ AZ ---

# 3.1. Публичная подсеть
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0] 
  map_public_ip_on_launch = true
  tags = {
    Name = "Public-Subnet"
  }
}

# 3.2. Приватная подсеть (для Backend, Frontend, DB)
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = aws_subnet.public.availability_zone 
  map_public_ip_on_launch = false
  tags = {
    Name = "Private-Subnet"
  }
}

# --- 4. Таблицы Маршрутизации (Route Tables) ---

# 4.1. Публичная Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "Public-RT"
  }
}

# Ассоциация публичной подсети с публичной Route Table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 4.2. Приватная Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Private-RT"
  }
}

# Ассоциация приватной подсети с приватной Route Table
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# --- 5. NAT Gateway (для исходящего трафика из Private Subnet)
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  # Assuming 'public' is the name of your public subnet resource in the VPC module
  subnet_id     = aws_subnet.public.id 
  depends_on    = [aws_internet_gateway.gw] # Зависит от создания GW

  tags = {
    Name = "${var.project_name}-nat-gw"
  }
}

# # Маршрут из Private RT через NAT Gateway
resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private.id 
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

# --- 6. VPC Interface Endpoints (для частного доступа к сервисам AWS)
# Все интерфейсные эндпоинты привязываются к Приватной подсети и SG Endpoints
# 6.1. Endpoint для SSM (Interface) - для безопасного SSH-доступа
#resource "aws_vpc_endpoint" "ssm" {
#  vpc_id              = aws_vpc.main.id
#  service_name        = "com.amazonaws.${var.aws_region}.ssm"
#  vpc_endpoint_type   = "Interface"
#  subnet_ids          = [aws_subnet.private.id]
#  # security_group_ids  = [aws_security_group.sg_vpc_endpoint.id]
#  security_group_ids  = [var.sg_vpc_endpoint_id]
#  private_dns_enabled = true
#}

# 6.2. Endpoint для EC2 Messages (Interface) - часть SSM
#resource "aws_vpc_endpoint" "ec2messages" {
#  vpc_id              = aws_vpc.main.id
#  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
#  vpc_endpoint_type   = "Interface"
#  subnet_ids          = [aws_subnet.private.id]
#  # security_group_ids  = [aws_security_group.sg_vpc_endpoint.id]
#  security_group_ids  = [var.sg_vpc_endpoint_id]
#  private_dns_enabled = true
#}

# 6.3. Endpoint для SSM Messages (Interface) - часть SSM
#resource "aws_vpc_endpoint" "ssm_messages" {
#  vpc_id              = aws_vpc.main.id
#  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
#  vpc_endpoint_type   = "Interface"
#  subnet_ids          = [aws_subnet.private.id]
#  # security_group_ids  = [aws_security_group.sg_vpc_endpoint.id]
#  security_group_ids  = [var.sg_vpc_endpoint_id]
#  private_dns_enabled = true
#}

# 6.4. Endpoint для ECR API (Interface) - для управления ECR
#resource "aws_vpc_endpoint" "ecr_api" {
#  vpc_id              = aws_vpc.main.id
#  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
#  vpc_endpoint_type   = "Interface"
#  subnet_ids          = [aws_subnet.private.id]
#  # security_group_ids  = [aws_security_group.sg_vpc_endpoint.id]
#  security_group_ids  = [var.sg_vpc_endpoint_id]
#  private_dns_enabled = true
#}

# 6.5. Endpoint для ECR DKR (Interface) - для скачивания Docker-образов
#resource "aws_vpc_endpoint" "ecr_dkr" {
#  vpc_id              = aws_vpc.main.id
#  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
#  vpc_endpoint_type   = "Interface"
#  subnet_ids          = [aws_subnet.private.id]
#  # security_group_ids  = [aws_security_group.sg_vpc_endpoint.id]
#  security_group_ids  = [var.sg_vpc_endpoint_id]
#  private_dns_enabled = true
#}

# 6.6. Endpoint для Secrets Manager (Interface) - КРИТИЧЕСКОЕ ДОБАВЛЕНИЕ
#resource "aws_vpc_endpoint" "secretsmanager" {
#  vpc_id              = aws_vpc.main.id
#  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
#  vpc_endpoint_type   = "Interface"
#  subnet_ids          = [aws_subnet.private.id]
#  security_group_ids  = [var.sg_vpc_endpoint_id]
#  private_dns_enabled = true
#}

# 7. Endpoint для S3 (Gateway - обязательно Gateway) - для доступа к стейту
#resource "aws_vpc_endpoint" "s3" {
#  vpc_id       = aws_vpc.main.id
#  service_name = "com.amazonaws.${var.aws_region}.s3"
#  vpc_endpoint_type = "Gateway"
#  route_table_ids = [aws_route_table.private.id] # Привязка к приватной RT
#}