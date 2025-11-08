#!/bin/bash
set -ex # -u означает завершать выполнение при обращении к неинициализированной переменной

# Определение переменной, переданной через Terraform
# FRONTEND_IP будет автоматически доступен в шаблоне
FRONTEND_IP="${FRONTEND_IP}"
BACKEND_IP="${BACKEND_IP}"

# 1. Установка Nginx (ИСПРАВЛЕНО: Используем yum для Amazon Linux 2)
echo "Установка Nginx..."
yum update -y
amazon-linux-extras install nginx1 -y # Устанавливаем Nginx из Amazon Extras
systemctl enable nginx
systemctl start nginx

# 2. Создание файла конфигурации Reverse Proxy
# Настраиваем Nginx на прослушивание порта 80 и проксирование на Frontend
echo "Настройка Nginx как Reverse Proxy..."
# NOTE: Для Amazon Linux 2 Nginx использует каталог /etc/nginx/nginx.conf
# Создадим новый файл конфигурации для Nginx, который будет работать как Reverse Proxy.
mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak || true
mkdir -p /etc/nginx/conf.d

#  4. Чистим основной nginx.conf от встроенного server{}...
echo "Чистим основной nginx.conf от встроенного server{}..."

cat <<'NGINX' > /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events { worker_connections 1024; }

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 4096;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    include /etc/nginx/conf.d/*.conf;
}
NGINX

cat <<EOF > /etc/nginx/conf.d/reverse-proxy.conf
# --- Upstream blocks ---
upstream frontend_app { server ${FRONTEND_IP}:80; }

server {
    listen 80 default_server;
    server_name _;

    # *** KEY POINT: Proxy traffic to the private IP of the Frontend instance ***
    # --- React SPA ---
    location / {
        proxy_pass http://frontend_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_connect_timeout 10s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # Обязательно, иначе React будет возвращать index.html на все запросы
        proxy_intercept_errors off;

        # ключ: если фронтенд SPA (React/Angular/Vue)
        try_files \$uri \$uri/ /index.html;
    }

    # --- Static React files ---
    location /static/ {
        proxy_pass http://frontend_app/static/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # --- Health check endpoint ---
    location /health {
        access_log off;
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
EOF

# 4. Проверка, включение и запуск Nginx
echo "Проверка и запуск Nginx..."
# Убедимся, что Nginx запускается при старте
# sudo systemctl enable nginx 
# Проверяем конфигурацию
sudo nginx -t
# Запускаем Nginx
sudo systemctl restart nginx

# 4. Проверка работы Reverse Proxy
#echo "Проверка Nginx: netstat -tuln | grep 80"
#sudo netstat -tuln | grep 80

echo "--- Reverse Proxy настроен: frontend=${FRONTEND_IP}, backend=${BACKEND_IP} ---"
