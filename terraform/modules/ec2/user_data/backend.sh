#!/bin/bash
set -ex # -u means to terminate execution when accessing an uninitialized variable

DB_USERNAME=""
DB_PASSWORD=""

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
ECR_BACKEND_URL="${ECR_BACKEND_URL}"
ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId)
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_URL"

#### "--- 4. Getting the database secret ---"
echo "--- 4. Getting the database secret ---"
SECRET_ARN="${DB_SECRET_ARN}"

MAX_RETRIES=10
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  DB_SECRET=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text --region $AWS_REGION 2>/dev/null)
  
  if [ $? -eq 0 ]; then
    echo "The secret has been successfully got."
    break
  fi
  
  echo "Error getting secret. Retrying in $((2**RETRY_COUNT)) seconds..."
  sleep $((2**RETRY_COUNT))
  RETRY_COUNT=$((RETRY_COUNT + 1))
done
if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "CRITICAL ERROR: Failed to get DB secret after $MAX_RETRIES attempts."
  exit 1
fi

#### "--- 5. Setting up database environment variables ---"
echo "--- 5. Setting up database environment variables ---"
DB_HOST="${DB_PRIVATE_IP}" # Use the IP passed from Terraform
DB_NAME="userstory"
DB_URL="jdbc:mariadb://$DB_HOST:3306/$DB_NAME"
DB_USERNAME=$(echo "$DB_SECRET" | jq -r '.username')
DB_PASSWORD=$(echo "$DB_SECRET" | jq -r '.password')

#### "--- 6. Waiting for MariaDB to be available on  DB_HOST:3306 ---"
echo "--- 6. Waiting for MariaDB to be available on $DB_HOST:3306 ---"
while ! nc -z $DB_HOST 3306; do
  echo "Waiting for database availability..."
  sleep 5
done
echo "The MariaDB database is available."

#### "--- 7. Pull and run the Backend container ---"
echo "--- 7. Pull and run the Backend container ---"
until docker pull $ECR_BACKEND_URL:latest; do
  echo "Waiting for ECR/Internet to pull Backend image..."
  sleep 10
done

docker run -d \
  --name userstory_backend \
  --restart unless-stopped \
  -p 8080:8080 \
  -e DB_USERSTORYPROJ_URL="jdbc:mariadb://${DB_HOST}:3306/userstory" \
  -e DB_USERSTORYPROJ_USER="$${DB_USERNAME}" \
  -e DB_USERSTORYPROJ_PASSWORD="$${DB_PASSWORD}" \
  ${ECR_BACKEND_URL}:latest

echo "Checking container startup..."
sleep 10
docker ps
docker logs userstory_backend --tail 20 || true

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

#### "--- 0. Backend installation script is complete ---"
echo "--- 0. Backend installation script is complete ---"
