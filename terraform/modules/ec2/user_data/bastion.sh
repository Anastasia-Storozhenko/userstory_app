#!/bin/bash
set -ex # -u means to terminate execution when accessing an uninitialized variable

FRONTEND_IP="${FRONTEND_IP}" # FRONTEND_IP will be automatically available in the template
BACKEND_IP="${BACKEND_IP}"   # Defining a variable passed through Terraform
echo "--- frontend=${FRONTEND_IP}, backend=${BACKEND_IP} ---"

echo "--- 1. Installing Nginx. Using yum for Amazon Linux 2 ---"
yum update -y -q
amazon-linux-extras install nginx1 -y
systemctl enable nginx
systemctl start nginx

echo "--- 2. Configuring Nginx to listen on port 80 and proxy to the Frontend ---"
# NOTE: For Amazon Linux 2, Nginx uses the /etc/nginx/nginx.conf directory
# Create a new configuration file for Nginx that will act as a Reverse Proxy
mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak || true
mkdir -p /etc/nginx/conf.d

echo "--- 3. Clearing the built-in server{} from the main nginx.conf ---"

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

echo "--- 4. Configuring reverse-proxy.conf ---"
cat <<'EOF' > /etc/nginx/conf.d/reverse-proxy.conf
# --- Upstream blocks ---
upstream frontend_app { server ${FRONTEND_IP}:80; }
upstream backend_app  { server ${BACKEND_IP}:8080; }

server {
    listen 80 default_server;
    server_name _;

    # --- 1. Static assets (React build) ---
    location /static/ {
        proxy_pass http://frontend_app/static/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # --- 2. API-requests to backend ---
    location /api/ {
        proxy_pass http://backend_app/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 10s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # --- 3. Alternative - if the frontend uses /projects ---
    location /projects/ {
        proxy_pass http://backend_app/projects/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 10s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # --- 4. Home page and frontend static files ---
    location / {
        proxy_pass http://frontend_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_intercept_errors off;
        try_files $uri $uri/ /index.html;
    }

    # --- 5. Health check ---
    location /health {
        access_log off;
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
EOF

echo " --- 5. Check and restart Nginx ---"
sudo nginx -t || (echo "Nginx config failed"; exit 1)
sudo systemctl restart nginx

echo " --- 6. Bastion installation script is complete ---"
