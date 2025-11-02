#!/bin/bash
set -ex # -u означает завершать выполнение при обращении к неинициализированной переменной

# 1. Базовый сетап: Установка Docker и AWS CLI
echo "--- 1. Запуск установки Docker и AWS CLI v2 ---"
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

yum install -y jq nmap-ncat

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
ECR_FRONTEND_URL="${ECR_FRONTEND_URL}"
BACKEND_PRIVATE_IP="${BACKEND_PRIVATE_IP}"

echo "--- Проверка доступности ECR ---"
until nc -zv 182000022338.dkr.ecr.us-east-1.amazonaws.com 443; do
  echo "ECR ещё недоступен, пробуем снова через 10 секунд..."
  sleep 10
done
echo "ECR доступен."

# /usr/local/bin/aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_FRONTEND_URL
# Попытка логина с ретраями (до 10 раз)
MAX_RETRIES=10
for i in $(seq 1 $MAX_RETRIES); do
  /usr/local/bin/aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_FRONTEND_URL && break
  echo "Попытка $i/$MAX_RETRIES не удалась, повтор через 10 секунд..."
  sleep 10
done

echo "--- 3. Проверка доступности Backend ---"
while ! nc -z $BACKEND_PRIVATE_IP 8080; do
  echo "Ожидание доступности Backend (${BACKEND_PRIVATE_IP}:8080)..."
  sleep 5
done
echo "Backend доступен."

echo "--- 4. Pull и запуск Frontend контейнера ---"
# Добавляем цикл ожидания для ECR/интернета
until docker pull $ECR_FRONTEND_URL:latest; do
  echo "Ожидание ECR/интернета для pull образа Frontend..."
  sleep 10
done

echo "--- 4.1. Добавление записи Backend в /etc/hosts ---"
cat << 'EOF' > /tmp/nginx_frontend.template
upstream backend_servers {
    server __BACKEND_IP__:8080;
}

server {
    listen 80;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://backend_servers/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
EOF

# Подставляем IP
sed "s|__BACKEND_IP__|${BACKEND_PRIVATE_IP}|g" /tmp/nginx_frontend.template > /tmp/nginx_frontend.conf

# echo "--- 5. Запуск контейнера Frontend ---"
# docker stop userstory_frontend || true
# docker rm userstory_frontend || true

# --- ЗАПУСК DOCKER С VOLUMES ---
# Монтируем наш кастомный файл внутрь контейнера (перезаписывает стандартный файл default.conf)
docker run -d \
  --name userstory_frontend \
  --restart unless-stopped \
  -p 80:80 \
  -v /tmp/nginx_frontend.conf:/etc/nginx/conf.d/default.conf \
  -e BACKEND_IP="$BACKEND_PRIVATE_IP" \
  $ECR_FRONTEND_URL:latest

sleep 10

docker ps
docker logs userstory_frontend --tail 20
curl -I http://localhost/api/projects || true

echo "--- Frontend успешно запущен ---"
