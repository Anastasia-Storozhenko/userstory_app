# Network ACL for VPC
resource "aws_network_acl" "main" {
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.project_name}-nacl"
  }
}

# Inbound rule: Allow internal traffic within a VPC
resource "aws_network_acl_rule" "allow_internal_inbound" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
}

# Inbound rule: Allow everything else (exmpl, access from the Internet)
resource "aws_network_acl_rule" "allow_all_inbound" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 200
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

# Outbound rule: Allow internal traffic
resource "aws_network_acl_rule" "allow_internal_outbound" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
}

# Outbound rule: Allow Internet access
resource "aws_network_acl_rule" "allow_all_outbound" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 200
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}
