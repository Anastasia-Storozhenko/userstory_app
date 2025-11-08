data "aws_region" "current" {}

# --- 1. VPC Module
module "vpc" {
  source = "../../modules/vpc"
  # Передаем переменные, если они отличаются от default в модуле
  project_name = var.project_prefix
  aws_region   = data.aws_region.current.name
  # Передаем SG для VPC Endpoints, который был создан выше
  # sg_vpc_endpoint_id  = module.security_groups.vpc_endpoint_sg_id
  vpc_cidr = var.vpc_cidr # Передаем исправленный CIDR
}

# --- 2. Security Groups Module (Должен быть первым, т.к. SG нужен VPC Endpoints)
module "security_groups" {
  source     = "../../modules/sg"
  vpc_id     = module.vpc.vpc_id # Передаем ID VPC из VPC модуля
  my_ip_cidr = var.my_ip_for_ssh
  # Порты по умолчанию: Backend 8080, DB 3306 - можно переопределить здесь
  vpc_cidr = var.vpc_cidr
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
  source = "../../modules/secrets"
  # Переменные могут быть оставлены по умолчанию или переопределены
  secret_name = "${var.project_prefix}-${var.env_name}-db-secret-v7"
}

# --- 6. IAM Module (for EC2 permissions)
module "iam" {
  source       = "../../modules/iam"
  project_name = var.project_prefix
  # Передаем ARN секрета из модуля Secrets Manager
  secret_arn = module.secrets.db_secret_arn
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

  # ПАРАМЕТРЫ ДЛЯ АВТОМАТИЗАЦИИ (user_data):
  aws_region       = data.aws_region.current.name
  ecr_frontend_url = module.ecr.frontend_ecr_uri
  ecr_backend_url  = module.ecr.backend_ecr_uri
  # db_secret_arn    = module.secrets.db_secret_arn
  db_secret_arn    = "arn:aws:secretsmanager:us-east-1:182000022338:secret:userstory-dev-db-secret-v7-ETNfQm"
  ecr_database_url = module.ecr.database_ecr_uri
}

# Вызов модуля Security Groups
#module "sg" {
#  source = "../../modules/sg" # Убедитесь, что это правильный путь к папке modules/sg

#  # Передача необходимых переменных
#  vpc_id         = module.vpc.vpc_id
#  my_ip_cidr     = var.my_ip_for_ssh
#  backend_port   = var.backend_port
#  db_port        = var.db_port
#  vpc_cidr       = var.vpc_cidr 
#}

# 1. РЕСУРС: ВРЕМЕННОЕ ОТКРЫТИЕ ДОСТУПА (создается)
#resource "aws_security_group_rule" "db_init_access" {
#  type                     = "ingress"
#  from_port                = 3306
#  to_port                  = 3306
#  protocol                 = "tcp"
#  # SG RDS (куда добавляется правило)
#  security_group_id        = module.sg.database_security_group_id
#  # SG Бастиона (источник трафика)
#  source_security_group_id = module.sg.bastion_lb_security_group_id
#  description              = "TEMP: Access for DB init from Bastion"
#}

# 2. РЕСУРС: ИНИЦИАЛИЗАЦИЯ БД
#resource "null_resource" "db_schema_initializer" {
#  # Зависимости
#  # Ссылаемся на OUTPUTS модулей, которые содержат соответствующие ресурсы:
#  depends_on = [
#    aws_security_group_rule.db_init_access,
#    module.ec2.bastion_public_ip, # Бастион
#    module.ec2.db_endpoint,       # RDS Endpoint
#    module.secrets.db_secret_arn  # ARN Секрета
#  ]
#
#  provisioner "remote-exec" {
#    inline = [
#      # 1. Ссылки на ресурсы с ИСПРАВЛЕННЫМИ output'ами:
#      "RDS_ENDPOINT='${module.ec2.db_endpoint}'",            # Используем output "db_endpoint"
#      "SECRET_ARN='${module.secrets.db_secret_arn}'",        # Используем output "db_secret_arn"

#      # 2. Установка утилит и получение учетных данных
#      "sudo yum update -y && sudo yum install -y awscli jq mysql",
#      
#      # "SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query SecretString --output text)",
#      "SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query SecretString --output text --region us-east-1)",
#      "DB_USER=$(echo $SECRET_JSON | jq -r '.username')",
#      "DB_PASSWORD=$(echo $SECRET_JSON | jq -r '.password')",

#      # 3. Загрузка и выполнение SQL-скрипта
#      # Используем более надежный относительный путь:
#      # "echo \"${file("./modules/rds/init_schema.sql")}\" > /tmp/init_schema.sql",
#      # "echo \"${file(path.root)/modules/rds/init_schema.sql}\" > /tmp/init_schema.sql",
#      "echo \"${file("../../modules/rds/init_schema.sql")}\" > /tmp/init_schema.sql",

#      "echo '--- Running Database Initialization Script ---'",
#      "mysql -h $RDS_ENDPOINT -P 3306 -u $DB_USER -p$DB_PASSWORD < /tmp/init_schema.sql",
#      "echo '--- Database Initialization Complete ---'"
#    ]
#  }

#  connection {
#    type        = "ssh"
#    user        = "ec2-user" 
#    private_key = file(var.private_key_path) 
#    # Используем output "bastion_public_ip"
#    host        = module.ec2.bastion_public_ip 
#  }
#}

# 3. РЕСУРС: АВТОМАТИЧЕСКОЕ ЗАКРЫТИЕ ДОСТУПА
#resource "null_resource" "db_cleanup" {
# Дождаться, пока инициализация БД будет завершена
#  depends_on = [null_resource.db_schema_initializer]

# Выполняется ЛОКАЛЬНО на вашей машине после завершения db_schema_initializer
#provisioner "local-exec" {
# command = "terraform destroy -target=aws_security_group_rule.db_init_access -auto-approve -lock=false -var private_key_path=temp -var my_ip_for_ssh=0.0.0.0/0 -var vpc_cidr=0.0.0.0/0 -var backend_port=8080 -var db_port=3306"
# command = "terraform destroy -target=aws_security_group_rule.db_init_access -auto-approve -lock=false -var \"private_key_path=temp\" -var \"my_ip_for_ssh=0.0.0.0/0\" -var \"vpc_cidr=0.0.0.0/0\" -var \"backend_port=8080\" -var \"db_port=3306\""

# Этот параметр гарантирует, что команда выполнится только один раз (при создании)
# Этого достаточно, т.к. при повторном apply ресурс будет создан снова.
#  when = create 
#}
#}

# --- 7. Интерфейсные Endpoints (используют SG для Endpoints)

# 7.1. Endpoint для Secrets Manager (Interface)
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type = "Interface"
  # Привязка к приватной подсети
  subnet_ids = [module.vpc.private_subnet_id]
  # SG теперь доступен, потому что модуль security_groups уже выполнен
  security_group_ids  = [module.security_groups.vpc_endpoint_sg_id]
  private_dns_enabled = true
}

# 7.2. Endpoint для ECR DKR (Interface) - для скачивания Docker-образов
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc.private_subnet_id]
  security_group_ids  = [module.security_groups.vpc_endpoint_sg_id]
  private_dns_enabled = true
}

# 7.3. Endpoint для ECR API (Interface) - для управления ECR
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc.private_subnet_id]
  security_group_ids  = [module.security_groups.vpc_endpoint_sg_id]
  private_dns_enabled = true
}

# 7.4. Endpoint для SSM (Interface) - для безопасного доступа к VM (Systems Manager)
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc.private_subnet_id]
  security_group_ids  = [module.security_groups.vpc_endpoint_sg_id]
  private_dns_enabled = true
}

# 7.5. Endpoint для EC2 Messages (Interface) - часть SSM
resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc.private_subnet_id]
  security_group_ids  = [module.security_groups.vpc_endpoint_sg_id]
  private_dns_enabled = true
}

# 7.6. Endpoint для SSM Messages (Interface) - часть SSM
resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc.private_subnet_id]
  security_group_ids  = [module.security_groups.vpc_endpoint_sg_id]
  private_dns_enabled = true
}

# --- Gateway Endpoint (не использует SG) ---

# 7.7. Endpoint для S3 (Gateway - обязательно Gateway) - для доступа к стейту и ECR
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  # Привязка к приватной таблице маршрутизации
  route_table_ids = [module.vpc.private_route_table_id]
}