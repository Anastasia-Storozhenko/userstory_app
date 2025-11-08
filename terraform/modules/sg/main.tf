# --- 1. Security Group: Bastion Host / Load Balancer (публичный доступ) ---
resource "aws_security_group" "bastion_lb" {
  name        = "Bastion-LB"
  description = "Allow SSH from specific IP and HTTP/S from Internet"
  vpc_id      = var.vpc_id

  # SSH доступ с вашего IP-адреса
  ingress {
    description = "SSH from Workstation"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # HTTP/HTTPS доступ из Интернета для Load Balancer
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 2. Security Group: Frontend Web-app (доступ только от LB) ---
resource "aws_security_group" "frontend" {
  name        = "Frontend-SG"
  description = "Allow traffic from LB and SSH from Bastion"
  vpc_id      = var.vpc_id

  # Доступ по порту 80 ТОЛЬКО от SG Load Balancer
  ingress {
    description     = "App traffic from Load Balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_lb.id]
  }

  # SSH доступ только с Bastion Host
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_lb.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#resource "aws_security_group_rule" "frontend_allow_bastion" {
#  type              = "ingress"
#  from_port         = 80
#  to_port           = 80
#  protocol          = "tcp"
#  security_group_id = aws_security_group.frontend.id
#  source_security_group_id = aws_security_group.bastion_lb.id
#}

resource "aws_security_group_rule" "vpc_endpoint_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.sg_vpc_endpoint.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from VPC Endpoints"
}

# --- 3. Security Group: Backend API (доступ только от Frontend) ---
resource "aws_security_group" "backend" {
  name        = "Backend-SG"
  description = "Allow traffic from Frontend and SSH from Bastion"
  vpc_id      = var.vpc_id

  # Доступ по порту Backend ТОЛЬКО от SG Frontend
  ingress {
    description     = "API traffic from Frontend"
    from_port       = var.backend_port
    to_port         = var.backend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  # SSH доступ только с Bastion Host
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_lb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 4. Security Group: Database (доступ только от Backend) ---
resource "aws_security_group" "database" {
  name        = "Database-SG"
  description = "Allow traffic from Backend only"
  vpc_id      = var.vpc_id

  # Доступ по порту БД ТОЛЬКО от SG Backend
  ingress {
    description     = "DB access from Backend"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  # SSH доступ к DB только с Bastion
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_lb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_vpc_endpoint" {
  name        = "VPC-Endpoint-SG"
  description = "Allow inbound HTTPS for VPC Endpoints"
  vpc_id      = var.vpc_id

  # Разрешить HTTPS (443) только из CIDR-блока VPC
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # Разрешить из любой точки в VPC
  }
}
