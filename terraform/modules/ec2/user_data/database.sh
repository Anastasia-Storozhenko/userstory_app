#!/bin/bash
set -ex # -u означает завершать выполнение при обращении к неинициализированной переменной

DB_ROOT_PASSWORD=""

echo "--- [1] Установка Docker, AWS CLI v2 и jq ---"
yum update -y

echo "--- Ожидание освобождения yum lock ---"
while sudo fuser /var/run/yum.pid >/dev/null 2>&1; do
  echo "yum занят другим процессом, ждем 10 секунд..."
  sleep 10
done

amazon-linux-extras install docker -y
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

yum install -y jq awscli unzip

# --- Проверка и установка AWS CLI v2 ---
if ! /usr/local/bin/aws --version >/dev/null 2>&1; then
  echo "Устанавливаем AWS CLI v2..."
  yum remove -y awscli || true
  curl --connect-timeout 10 --retry 5 --retry-delay 5 -o "awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
  unzip -q awscliv2.zip
  ./aws/install
  rm -rf awscliv2.zip aws
else
  echo "AWS CLI v2 уже установлена: $(/usr/local/bin/aws --version)"
fi

export PATH=$PATH:/usr/local/bin

# 2. ECR Аутентификация
echo "--- [2] Авторизация в AWS ECR ---"
AWS_REGION="${AWS_REGION}"
ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId)
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_URL"
MAX_RETRIES=5
for ((i=1; i<=MAX_RETRIES; i++)); do
  if /usr/local/bin/aws ecr get-login-password --region "$AWS_REGION" | \
     docker login --username AWS --password-stdin "$ECR_URL"; then
    echo "ECR login succeeded."
    break
  else
    echo "ECR login failed (attempt $i/$MAX_RETRIES), retrying in $((5*i))s..."
    sleep $((5*i))
  fi
done
if [ $i -gt $MAX_RETRIES ]; then
  echo "CRITICAL: ECR login failed after $MAX_RETRIES attempts"
  exit 1
fi

echo "--- [3] Получаем секрет БД из Secrets Manager ---"
SECRET_ARN="${DB_SECRET_ARN}"

MAX_RETRIES=5
for ((i=1; i<=MAX_RETRIES; i++)); do
  DB_SECRET=$(/usr/local/bin/aws secretsmanager get-secret-value \
    --secret-id "$SECRET_ARN" \
    --query SecretString --output text --region "$AWS_REGION" 2>/dev/null) && break
  echo "Не удалось получить секрет, повтор $i..."
  sleep $((2**i))
done

if [ -z "$DB_SECRET" ]; then
  echo "КРИТИЧЕСКАЯ ОШИБКА: секрет не получен"
  exit 1
fi

DB_ROOT_PASSWORD=$(echo "$DB_SECRET" | jq -r '.password')
DB_USER=$(echo "$DB_SECRET" | jq -r '.username')
DB_NAME="userstory"

echo "DEBUG: DB_USER=$DB_USER"
echo "DEBUG: DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD"

echo "--- [4] Запуск контейнера MariaDB из ECR ---"
docker run -d \
  --name mariadb_db \
  --network host \
  -p 3306:3306 \
  -e MARIADB_ROOT_PASSWORD="$${DB_ROOT_PASSWORD}" \
  -e MARIADB_DATABASE="${DB_NAME}" \
  -e MARIADB_USER="${DB_USER}" \
  -e MARIADB_PASSWORD="$${DB_ROOT_PASSWORD}" \
  ${DB_IMAGE_URI}

echo "--- [5] Проверка запуска контейнера ---"
sleep 10
docker ps
docker logs mariadb_db || true

echo "--- MariaDB успешно запущена из ECR образа ---"
