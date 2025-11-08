#######################################
# Network ACL для VPC
#######################################

resource "aws_network_acl" "main" {
  vpc_id = var.vpc_id

  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.project_name}-nacl"
  }
}

#######################################
# Inbound rules
#######################################

# Разрешаем внутренний трафик внутри VPC
resource "aws_network_acl_rule" "allow_internal_inbound" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
}

# Разрешаем всё остальное (например, доступ из интернета)
resource "aws_network_acl_rule" "allow_all_inbound" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 200
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

#######################################
# Outbound rules
#######################################

# Разрешаем внутренний трафик
resource "aws_network_acl_rule" "allow_internal_outbound" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
}

# Разрешаем выход в интернет
resource "aws_network_acl_rule" "allow_all_outbound" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 200
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}