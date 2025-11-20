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
ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId)
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

sleep 30 ## Waiting 40 sec for network/DNS/ECR routing...

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

#### "--- 4. Getting the database secret ---"
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

#### "--- 5. Run the Database container ---"
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

# --- Enable Docker integration
echo "Setting up Datadog Docker integration..."
cat <<EOF | sudo tee /etc/datadog-agent/conf.d/docker.d/conf.yaml
init_config:

instances:
  - url: "unix://var/run/docker.sock"
    new_tag_names: true
EOF

# --- Add global tags and enable Docker in the main config
sudo sed -i "s|^# logs_enabled: false|logs_enabled: true|" /etc/datadog-agent/datadog.yaml
sudo sed -i "s|^# apm_config:|apm_config:\n  enabled: true|" /etc/datadog-agent/datadog.yaml

cat <<EOF | sudo tee -a /etc/datadog-agent/datadog.yaml
tags:
  - env:${DD_ENV}
  - role:${DD_ROLE}
  - service:docker
process_config:
  enabled: "true"
container_collect_all: true
EOF

systemctl enable datadog-agent
systemctl restart datadog-agent

echo "DataDog Agent installed and started ---"

#### "--- 0. Database installation script is complete ---"
echo "--- 0. Database installation script is complete ---"
