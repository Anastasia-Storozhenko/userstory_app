# --- 1. Security Group: Bastion Host / Load Balancer (public access) ---
resource "aws_security_group" "bastion_lb" {
  name        = "${var.project_name}-Bastion-LB"
  description = "Allow SSH from specific IP and HTTP/S from Internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from personal workstation"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "HTTP from Internet for Load Balancer"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from Internet for Load Balancer"
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

  tags = {
    Name = "Bastion-LB"
  }
}

# --- 2. Security Group: Frontend Web-app (access only from Bastion) ---
resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-Frontend-SG"
  description = "Allow HTTP traffic from LB and SSH for maintenance"
  vpc_id      = var.vpc_id

  # Access on port 80 only from SG Load Balancer
  ingress {
    description     = "HTTP from Bastion/LB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_lb.id]
  }

  # SSH access only from Bastion Host
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_lb.id]
  }
  
  ingress {
    description = "DEBUG: Allow all TCP from Bastion (SHOULD BE REMOVED ON PROD)"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_lb.id]
  }

  ingress {
    description     = "ICMP from Bastion (for ping)"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.bastion_lb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [aws_security_group.bastion_lb]

  tags = {
    Name = "Frontend-SG"
  }
}

# --- 3. Security Group: Backend API (access only from Frontend) ---
resource "aws_security_group" "backend" {
  name        = "${var.project_name}-Backend-SG"
  description = "Allow traffic from Frontend and SSH from Bastion"
  vpc_id      = var.vpc_id

  # Access via Backend port from SG Frontend
  ingress {
    description     = "API traffic from Frontend"
    from_port       = var.backend_port
    to_port         = var.backend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  # Backend Port Access from SG Bastion
  ingress {
    description     = "Proxy/API from Bastion/LB"
    from_port       = var.backend_port
    to_port         = var.backend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_lb.id]
  }

  # SSH access only from Bastion Host
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_lb.id]
  }

  ingress {
    description = "DEBUG: Allow all TCP from Bastion (SHOULD BE REMOVED ON PROD)"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_lb.id]
  }

  ingress {
    description     = "ICMP from Bastion (for ping)"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.bastion_lb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [aws_security_group.frontend, aws_security_group.bastion_lb]

  tags = {
    Name = "Backend-SG"
  }
}

# --- 4. Security Group: Database (access only from Backend) ---
resource "aws_security_group" "database" {
  name        = "${var.project_name}-Database-SG"
  description = "Allow DB access from Backend and SSH from Bastion"
  vpc_id      = var.vpc_id

  # Access via DB port only from SG Backend
  ingress {
    description     = "DB access from Backend"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  # SSH access to the DB only with Bastion
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_lb.id]
  }

  ingress {
    description     = "ICMP from Bastion"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.bastion_lb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [aws_security_group.backend, aws_security_group.bastion_lb]

  tags = {
    Name = "Database-SG"
  }
}

# --- 5. Security Group: VPC Enfpoint ---
resource "aws_security_group" "sg_vpc_endpoint" {
  name        = "${var.project_name}-VPC-Endpoint-SG"
  description = "Allow inbound HTTPS for VPC Endpoints"
  vpc_id      = var.vpc_id

  # Allow HTTPS (443) only from VPC CIDR block
  ingress {
    description = "HTTPS from VPC CIDR"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # Allow from anywhere in VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "VPC-Endpoint-SG"
  }
}
