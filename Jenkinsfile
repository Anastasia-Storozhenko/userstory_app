pipeline {
    agent any
    tools {
        nodejs 'nodejs-20.11.0'
        jdk 'jdk17'
        maven 'maven-3.6.3'
        terraform 'terraform-1.13.4'
    }
    environment {
        DB_USER = credentials('db-credentials')
        DB_USERSTORYPROJ_URL = 'jdbc:mariadb://10.0.2.195:3306/userstory'
        DB_USERSTORYPROJ_USER = "${DB_USER_USR}"
        DB_USERSTORYPROJ_PASSWORD = "${DB_USER_PSW}"
        DOCKER_REGISTRY = '182000022338.dkr.ecr.us-east-1.amazonaws.com'
        FRONTEND_IMAGE = "${DOCKER_REGISTRY}/userstory-frontend-repo:latest"
        BACKEND_IMAGE = "${DOCKER_REGISTRY}/userstory-backend-repo:latest"
        DOCKER_HOST = 'tcp://192.168.56.20:2375'
        COMPOSE_HTTP_TIMEOUT = '120'

        SONAR_TOKEN = credentials('sonarcloud-token')
        SONAR_PROJECT_KEY = 'Anastasia-Storozhenko_userstory_app'
        SONAR_ORG = 'anastasia-storozhenko'
        SONAR_HOST_URL = 'https://sonarcloud.io'

        TF_VAR_project_prefix = 'userstory'
        TF_VAR_env_name = 'dev'
        TF_VAR_my_ip_for_ssh = '0.0.0.0/0'
        TF_VAR_vpc_cidr = '10.0.0.0/16'
        TF_VAR_backend_port = '8080'
        TF_VAR_db_port = '3306'
        TF_VAR_private_key_path = './terraform/envs/dev/userstory_key'
    }
    stages {
        stage('Check Docker Host') {
            steps {
                script {
                    sh '''
                        nc -zv 192.168.56.20 2375 || { echo "Cannot connect to Docker host"; exit 1; }
                        docker -H ${DOCKER_HOST} info --format '{{.ServerVersion}}' || exit 1
                        docker -H ${DOCKER_HOST} buildx version || { echo "Buildx not installed"; exit 1; }
                    '''
                }
            }
        }
        stage('Create Docker Network') {
            steps {
                script {
                    sh '''
                        docker -H ${DOCKER_HOST} network inspect app-network || \
                        docker -H ${DOCKER_HOST} network create app-network
                    '''
                }
            }
        }
        stage('Checkout') {
            steps {
                git branch: 'master', credentialsId: 'github-credentials', url: 'https://github.com/Anastasia-Storozhenko/userstory_app.git'
            }
        }
        stage('Clean Old Images') {
            steps {
                script {
                    sh "docker -H ${DOCKER_HOST} image prune -f"
                    sh "docker -H ${DOCKER_HOST} system prune -f --volumes"
                }
            }
        }
        stage('Terraform Init & Plan') {
            steps {
                dir('terraform/envs/dev') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh '''
                            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                            export AWS_DEFAULT_REGION=us-east-1
                            terraform --version
                            terraform init
                            terraform plan -out=tfplan -var="project_prefix=${TF_VAR_project_prefix}" -var="env_name=${TF_VAR_env_name}"
                        '''
                    }
                }
            }
        }
        stage('Terraform Apply') {
            steps {
                dir('terraform/envs/dev') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh '''
                            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                            export AWS_DEFAULT_REGION=us-east-1
                            terraform apply -auto-approve tfplan
                        '''
                    }
                }
            }
        }
        stage('Install AWS CLI') {
            steps {
                sh '''
                    if [ -f /etc/debian_version ]; then
                        sudo apt-get update
                        sudo apt-get install -y unzip
                    elif [ -f /etc/redhat-release ]; then
                        sudo yum install -y unzip
                    else
                        echo "Невідомий дистрибутив, встановіть unzip вручну"
                        exit 1
                    fi
                    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                    unzip -o awscliv2.zip
                    sudo ./aws/install --update
                    rm -rf awscliv2.zip aws
                '''
            }
        }
        stage('Validate Infrastructure') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                        export AWS_DEFAULT_REGION=us-east-1
                        aws ec2 describe-vpcs --filters "Name=tag:Name,Values=userstory-vpc" || echo "VPC not found"
                        aws ec2 describe-instances --filters "Name=tag:Name,Values=userstory-frontend" || echo "EC2 not found"
                        aws ec2 describe-instances --filters "Name=tag:Name,Values=userstory-database" || echo "Database EC2 not found"
                        aws ecr describe-repositories --repository-names userstory-frontend || echo "ECR not found"
                    '''
                }
            }
        }
        stage('Build Frontend') {
            steps {
                dir('frontend') {
                    sh 'npm install'
                    sh 'CI=false npm run build'
                }
            }
        }
        stage('Build Backend') {
            steps {
                dir('backend') {
                    sh 'mvn clean package -DskipTests'
                }
            }
        }
        stage('Build and Push Docker Images') {
            steps {
                script {
                    withCredentials([
                        string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh '''
                            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                            export AWS_DEFAULT_REGION=us-east-1
                            aws ecr get-login-password --region us-east-1 | docker -H ${DOCKER_HOST} login --username AWS --password-stdin ${DOCKER_REGISTRY}
                            cd frontend
                            docker -H ${DOCKER_HOST} buildx build --tag ${FRONTEND_IMAGE} . --push
                            cd ../backend
                            docker -H ${DOCKER_HOST} buildx build --tag ${BACKEND_IMAGE} . --push
                        '''
                    }
                }
            }
        }
        stage('Deploy') {
            steps {
                script {
                    sh '''
                        docker-compose -H ${DOCKER_HOST} -f docker-compose.yml down || true
                        docker -H ${DOCKER_HOST} ps -q | xargs -r docker -H ${DOCKER_HOST} stop || true
                        docker -H ${DOCKER_HOST} ps -a -q | xargs -r docker -H ${DOCKER_HOST} rm || true
                        docker-compose -H ${DOCKER_HOST} -f docker-compose.yml up -d --force-recreate
                        sleep 300
                        docker -H ${DOCKER_HOST} ps -a
                        docker -H ${DOCKER_HOST} logs userstory-frontend
                        docker -H ${DOCKER_HOST} logs userstory-backend
                    '''
                }
            }
        }
        stage('Test Application') {
            steps {
                script {
                    sh '''
                        docker -H ${DOCKER_HOST} exec userstory-frontend curl -s -f http://backend:8080/api/projects || echo 'API check failed'
                    '''
                }
            }
        }
    }
    post {
        always {
            sh "docker -H ${DOCKER_HOST} logout ${DOCKER_REGISTRY}"
        }
    }
}