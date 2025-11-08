#!/bin/bash
set -ex # -u означает завершать выполнение при обращении к неинициализированной переменной

# 1. Базовый сетап: Установка Docker, AWS CLI и jq
echo "--- 1. Запуск установки Docker, AWS CLI v2 и jq ---"
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

yum install -y jq net-tools
yum install -y nmap-ncat

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
echo "--- 2. ECR Аутентификация ---"
AWS_REGION="${AWS_REGION}"
ECR_BACKEND_URL="${ECR_BACKEND_URL}"
# /usr/local/bin/aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_BACKEND_URL
ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId)
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_URL"

# 3. Получение секрета БД
echo "--- 3. Получение секрета БД ---"
SECRET_ARN="${DB_SECRET_ARN}"

MAX_RETRIES=10
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  DB_SECRET=$(/usr/local/bin/aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text --region $AWS_REGION 2>/dev/null)
  
  if [ $? -eq 0 ]; then
    echo "Секрет успешно получен."
    break
  fi
  
  echo "Ошибка получения секрета. Повторная попытка через $((2**RETRY_COUNT)) секунд..."
  sleep $((2**RETRY_COUNT))
  RETRY_COUNT=$((RETRY_COUNT + 1))
done
if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "КРИТИЧЕСКАЯ ОШИБКА: Не удалось получить секрет БД после $MAX_RETRIES попыток."
  exit 1
fi

# 4. Извлечение учетных данных и настройка ENV
echo "--- 4. Настройка переменных окружения БД ---"
DB_USERNAME=$(echo "$DB_SECRET" | jq -r '.username')
DB_PASSWORD=$(echo "$DB_SECRET" | jq -r '.password')
DB_HOST="${DB_PRIVATE_IP}" # Используем IP, переданный из Terraform
DB_NAME="userstory"
DB_URL="jdbc:mariadb://$DB_HOST:3306/$DB_NAME"

# 5. Ожидание доступности MariaDB
echo "--- 5. Ожидание доступности MariaDB на $DB_HOST:3306 ---"
while ! nc -z $DB_HOST 3306; do
  echo "Ожидание доступности базы данных..."
  sleep 5
done
echo "База данных доступна."

# 6. Pull и запуск Backend контейнера
echo "--- 6. Pull и запуск Backend контейнера ---"
# Добавляем цикл ожидания для ECR/интернета
until docker pull $ECR_BACKEND_URL:latest; do
  echo "Ожидание ECR/интернета для pull образа Backend..."
  sleep 10
done

docker run -d \
  --name userstory_backend \
  --restart unless-stopped \
  -p 8080:8080 \
  -e DB_USERSTORYPROJ_URL="jdbc:mariadb://${DB_HOST}:3306/userstory" \
  -e DB_USERSTORYPROJ_USER="${DB_USERNAME}" \
  -e DB_USERSTORYPROJ_PASSWORD="${DB_PASSWORD}" \
  ${ECR_BACKEND_URL}:latest

sleep 10
docker ps
docker logs userstory_backend --tail 20

echo "--- 7. Настройка автозапуска backend контейнера ---"
cat << 'EOF' > /etc/systemd/system/backend-autostart.service
[Unit]
Description=Ensure backend container is running
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/docker start userstory_backend || /usr/bin/docker run -d \
  --name userstory_backend \
  --restart unless-stopped \
  -p 8080:8080 \
  -e DB_USERSTORYPROJ_URL="jdbc:mariadb://${DB_HOST}:3306/userstory" \
  -e DB_USERSTORYPROJ_USER="${DB_USERNAME}" \
  -e DB_USERSTORYPROJ_PASSWORD="${DB_PASSWORD}" \
  ${ECR_BACKEND_URL}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable backend-autostart.service

echo "Скрипт установки Backend завершен."
