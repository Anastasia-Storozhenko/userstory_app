# --- 1. IAM Policy Document: Trust relationship for EC2 ---
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# --- 2. IAM Role for EC2 Instances ---
resource "aws_iam_role" "ec2_role" {
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  # managed_policy_arns был удален отсюда, чтобы устранить предупреждение.
}

# --- 2.1. Attach AmazonSSMManagedInstanceCore Policy (New Recommended Syntax) ---
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# --- 3. IAM Policy Document: Secrets Manager Read Access ---
data "aws_iam_policy_document" "secrets_read_policy" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcEndpoints",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs"
    ]
    resources = ["*"]
  }
}

#data "aws_iam_policy_document" "secrets_read_policy" {
#  statement {
#    effect  = "Allow"
#    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
#    resources = [var.secret_arn] # Разрешаем только для нашего секрета!
#  }
#}

# --- 4. IAM Policy ---
resource "aws_iam_policy" "secrets_read_policy" {
  name        = "${var.project_name}-secrets-read-policy"
  description = "Allows EC2 instances to read the specific database secret."
  policy      = data.aws_iam_policy_document.secrets_read_policy.json
}

# --- 5. Attach Secrets Policy to Role ---
resource "aws_iam_role_policy_attachment" "secrets_read_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets_read_policy.arn
}

# --- 6. IAM Instance Profile (необходим для привязки роли к EC2) ---
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# --- 7. IAM Policy Document: ECR Read Access ---
data "aws_iam_policy_document" "ecr_read_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    # GetAuthorizationToken требует Resource = "*"
    resources = ["*"] 
  }
}

# --- 8. IAM Policy: ECR Read ---
resource "aws_iam_policy" "ecr_read_policy" {
  name        = "${var.project_name}-ecr-read-policy"
  description = "Allows EC2 instances to authenticate with ECR and pull images."
  policy      = data.aws_iam_policy_document.ecr_read_policy.json
}

# --- 9. Attach ECR Policy to Role ---
resource "aws_iam_role_policy_attachment" "ecr_read_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ecr_read_policy.arn
}