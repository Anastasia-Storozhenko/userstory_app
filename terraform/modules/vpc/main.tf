# --- 1. AZ list to select first (for one zone) ---
data "aws_availability_zones" "available" {
  state = "available"
}

# --- 1. Main VPC net ---
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

# --- 3. Subnets in ONE AZ ---
# 3.1. Public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0] 
  map_public_ip_on_launch = true
  
  tags = {
    Name = "Public-Subnet"
  }
}

# 3.2. Private subnet (for Backend, Frontend and DB)
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = aws_subnet.public.availability_zone 
  map_public_ip_on_launch = false
  
  tags = {
    Name = "Private-Subnet"
  }
}

# --- 4. Route Tables ---
# 4.1. Public Route Table
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

# 4.2. Association of a public subnet with a public Route Table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 4.3. Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "Private-RT"
  }
}

# 4.4. Association of a private subnet with a private Route Table
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# --- 5. NAT Gateway (for outgoing traffic from the Private Subnet)
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  
  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.gw]

  tags = {
    Name = "${var.project_name}-nat-gw"
  }
}

# Route from Private RT via NAT Gateway
resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private.id 
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}
