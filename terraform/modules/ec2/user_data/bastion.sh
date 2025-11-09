#!/bin/bash
set -ex # -u means to terminate execution when accessing an uninitialized variable

FRONTEND_IP="${FRONTEND_IP}" # FRONTEND_IP will be automatically available in the template
BACKEND_IP="${BACKEND_IP}"   # Defining a variable passed through Terraform
echo "--- frontend=${FRONTEND_IP}, backend=${BACKEND_IP} ---"

#### "--- 1. Installing Nginx. Using yum for Amazon Linux 2 ---"
echo "--- 1. Installing Nginx. Using yum for Amazon Linux 2 ---"
yum update -y -q
amazon-linux-extras install nginx1 -y
systemctl enable nginx
systemctl start nginx

#### "--- 2. Configuring Nginx to listen on port 80 and proxy to the Frontend ---"
echo "--- 2. Configuring Nginx to listen on port 80 and proxy to the Frontend ---"
# NOTE: For Amazon Linux 2, Nginx uses the /etc/nginx/nginx.conf directory
# Create a new configuration file for Nginx that will act as a Reverse Proxy
mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak || true
mkdir -p /etc/nginx/conf.d

#### "--- 3. Clearing the built-in server{} from the main nginx.conf ---"
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

#### "--- 4. Configuring reverse-proxy.conf ---"
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

#### "--- 5. Check and restart Nginx ---"
echo "--- 5. Check and restart Nginx ---"
sudo nginx -t || (echo "Nginx config failed"; exit 1)
sudo systemctl restart nginx

#### "--- 6. Installing DataDog Agent ---"
echo "--- 6. Installing DataDog Agent ---"
DD_SITE="us5.datadoghq.com"
DD_ENV="${DD_ENV}"
DD_ROLE="${DD_ROLE}"
AWS_REGION="us-east-1"
SECRET_ARN="${DD_SECRET_ARN}"

yum install -y curl jq

echo "Fetching Datadog API key from Secrets Manager..."
for i in {1..5}; do
  DD_API_KEY=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query 'SecretString' --output text --region "$AWS_REGION" 2>/dev/null | jq -r '.api_key')
  if [ -n "$DD_API_KEY" ] && [ "$DD_API_KEY" != "null" ]; then
    echo "Datadog key retrieved successfully."
    break
  fi
  echo "Retry $i... waiting for secret availability"
  sleep $((2*i))
done
if [ -z "$DD_API_KEY" ] || [ "$DD_API_KEY" = "null" ]; then
  echo "CRITICAL: Failed to retrieve valid Datadog API key"
  exit 1
fi

echo "Installing Datadog agent with retrieved key..."
DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=$DD_API_KEY DD_SITE=$DD_SITE bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"

cat <<EOF | sudo tee -a /etc/datadog-agent/datadog.yaml
tags:
  - env:$DD_ENV
  - role:$DD_ROLE
EOF

systemctl enable datadog-agent
systemctl restart datadog-agent

echo "DataDog Agent installed and started ---"

#### "--- 0. Bastion installation script is complete ---"
echo "--- 0. Bastion installation script is complete ---"
