#!/bin/bash
set -ex # -u means to terminate execution when accessing an uninitialized variable

DB_USERNAME=""
DB_PASSWORD=""

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
ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId)
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_URL"

MAX_RETRIES=5
for ((i=1; i<=MAX_RETRIES; i++)); do
  if aws ecr get-login-password --region "$AWS_REGION" | \
     docker login --username AWS --password-stdin "$ECR_URL"; then
    echo "ECR login succeeded."
    break
  else
    echo "ECR login failed (attempt $i/$MAX_RETRIES), retrying in $((5*i))s..."
    sleep $((5*i))
  fi
done
if [ $i -gt $MAX_RETRIES ]; then
  echo "CRITICAL ERROR: ECR login failed after $MAX_RETRIES attempts."
  exit 1
fi

echo "--- 4. Getting the database secret ---"
SECRET_ARN="${DB_SECRET_ARN}"

MAX_RETRIES=5
for ((i=1; i<=MAX_RETRIES; i++)); do
  DB_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_ARN" \
    --query SecretString --output text --region "$AWS_REGION" 2>/dev/null) && break
  echo "Error getting secret. Retrying in $i..."
  sleep $((2**i))
done
if [ -z "$DB_SECRET" ]; then
  echo "CRITICAL ERROR: Failed to get DB secret."
  exit 1
fi

DB_NAME="userstory"
DB_PASSWORD=$(echo "$DB_SECRET" | jq -r '.password')
DB_USERNAME=$(echo "$DB_SECRET" | jq -r '.username')

echo "DEBUG: DB_USERNAME=$DB_USERNAME"
echo "DEBUG: DB_PASSWORD=$DB_PASSWORD"

echo "--- 5. Run the Database container ---"
docker run -d \
  --name mariadb_db \
  --network host \
  -p 3306:3306 \
  -e MARIADB_ROOT_PASSWORD="$${DB_PASSWORD}" \
  -e MARIADB_DATABASE="${DB_NAME}" \
  -e MARIADB_USER="${DB_USERNAME}" \
  -e MARIADB_PASSWORD="$${DB_PASSWORD}" \
  ${DB_IMAGE_URI}

echo "Checking container startup..."
sleep 10
docker ps
docker logs mariadb_db --tail 20 || true

echo "--- 6. Database installation script is complete ---"
