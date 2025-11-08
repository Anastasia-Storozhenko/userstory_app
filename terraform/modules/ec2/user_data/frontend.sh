#!/bin/bash
set -ex # -u means to terminate execution when accessing an uninitialized variable

echo "--- 1. Basic Setup: Installing Docker, AWS CLI, and jq ---"
yum update -y -q

echo "--- 2. Waiting for yum lock to be released ---"
while sudo fuser /var/run/yum.pid >/dev/null 2>&1; do
  echo "Yum is busy with another process, wait 10 seconds..."
  sleep 10
done

yum install -y jq net-tools nmap-ncat awscli unzip
amazon-linux-extras install docker -y

systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

export PATH=$PATH:/usr/local/bin

echo "--- 3. ECR Authentication ---"
AWS_REGION="${AWS_REGION}"
ECR_FRONTEND_URL="${ECR_FRONTEND_URL}"
BACKEND_PRIVATE_IP="${BACKEND_PRIVATE_IP}"

echo "Checking ECR availability"
until nc -zv 182000022338.dkr.ecr.us-east-1.amazonaws.com 443; do
  echo "ECR is not yet available, try again in 10 seconds..."
  sleep 10
done
echo "ECR is available."

MAX_RETRIES=10
for i in $(seq 1 $MAX_RETRIES); do
  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_FRONTEND_URL && break
  echo "Attempt $i/$MAX_RETRIES failed, retrying in 10 seconds..."
  sleep 10
done

echo "--- 4. Backend availability check ---"
while ! nc -z $BACKEND_PRIVATE_IP 8080; do
  echo "Waiting for Backend availability (${BACKEND_PRIVATE_IP}:8080)..."
  sleep 5
done
echo "Backend is available."

echo "--- 5. Pull and run Frontend container ---"
until docker pull $ECR_FRONTEND_URL:latest; do
  echo "Waiting for ECR/Internet to pull Frontend image..."
  sleep 10
done

echo "--- 6. Adding a Backend entry to /etc/hosts ---"
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

sed "s|__BACKEND_IP__|${BACKEND_PRIVATE_IP}|g" /tmp/nginx_frontend.template > /tmp/nginx_frontend.conf

echo "--- 7. Run the Frontend container ---"
docker run -d \
  --name userstory_frontend \
  --restart unless-stopped \
  -p 80:80 \
  -v /tmp/nginx_frontend.conf:/etc/nginx/conf.d/default.conf \
  -e BACKEND_IP="$BACKEND_PRIVATE_IP" \
  $ECR_FRONTEND_URL:latest

echo "Checking container startup..."
sleep 10
docker ps
docker logs userstory_frontend --tail 20 || true

echo "--- 8. Frontend installation script is complete ---"
