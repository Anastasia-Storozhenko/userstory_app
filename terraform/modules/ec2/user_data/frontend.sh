#!/bin/bash
set -ex # -u means to terminate execution when accessing an uninitialized variable

#### "--- 1. Basic Setup: Installing Docker, AWS CLI, and jq ---"
echo "--- 1. Basic Setup: Installing Docker, AWS CLI, and jq ---"
yum update -y -q

#### "--- 2. Waiting for yum lock to be released ---"
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

echo "Waiting for Docker to become ready"
for i in {1..10}; do
  if sudo docker info >/dev/null 2>&1; then
    echo "Done! Docker is ready."
    break
  fi
  echo "Docker isn't ready yet... retry $i"
  sleep 5
done

export PATH=$PATH:/usr/local/bin

#### "--- 3. ECR Authentication ---"
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

#### "--- 4. Backend availability check ---"
echo "--- 4. Backend availability check ---"
while ! nc -z $BACKEND_PRIVATE_IP 8080; do
  echo "Waiting for Backend availability (${BACKEND_PRIVATE_IP}:8080)..."
  sleep 5
done
echo "Backend is available."

#### "--- 5. Pull and run Frontend container ---"
echo "--- 5. Pull and run Frontend container ---"
until docker pull $ECR_FRONTEND_URL:latest; do
  echo "Waiting for ECR/Internet to pull Frontend image..."
  sleep 10
done

#### "--- 6. Adding a Backend entry to /etc/hosts ---"
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

#### "--- 7. Run the Frontend container ---"
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

#### "--- 8. Installing DataDog Agent ---"
echo "--- 8. Installing DataDog Agent ---"
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

#### "--- 0. Frontend installation script is complete ---"
echo "--- 0. Frontend installation script is complete ---"
