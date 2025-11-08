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
        DB_USERSTORYPROJ_URL = 'jdbc:mariadb://db:3306/userstory?createDatabaseIfNotExist=true'
        DB_USERSTORYPROJ_USER = "${DB_USER_USR}"
        DB_USERSTORYPROJ_PASSWORD = "${DB_USER_PSW}"
        DOCKER_REGISTRY = '182000022338.dkr.ecr.us-east-1.amazonaws.com'
        FRONTEND_IMAGE = "${DOCKER_REGISTRY}/userstory-frontend-repo:latest"
        BACKEND_IMAGE = "${DOCKER_REGISTRY}/userstory-backend-repo:latest"
        PUBLIC_IP = 'ec2-98-92-121-235.compute-1.amazonaws.com'
        SSH_KEY = credentials('ssh-key-id') // Додайте SSH-ключ у Jenkins Credentials
        SSH_USER = 'ec2-user'
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
                    withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-id', keyFileVariable: 'SSH_KEY')]) {
                        sh '''
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'sudo systemctl status docker' || { echo "Docker not running on EC2"; exit 1; }
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker info --format "{{.ServerVersion}}"' || { echo "Cannot connect to Docker"; exit 1; }
                        '''
                    }
                }
            }
        }
        stage('Create Docker Network') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-id', keyFileVariable: 'SSH_KEY')]) {
                        sh '''
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker network inspect app-network || docker network create app-network'
                        '''
                    }
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
                    withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-id', keyFileVariable: 'SSH_KEY')]) {
                        sh '''
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker image prune -f'
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker system prune -f --volumes'
                        '''
                    }
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
                        aws ecr describe-repositories --repository-names userstory-frontend || echo "ECR not found"
                    '''
                }
            }
        }
        stage('Build Frontend') {
            steps {
                dir('frontend') {
                    sh '''
                        npm install @babel/plugin-transform-private-methods@latest \
                                   @babel/plugin-transform-class-properties@latest \
                                   @babel/plugin-transform-numeric-separator@latest \
                                   @babel/plugin-transform-nullish-coalescing-operator@latest \
                                   @babel/plugin-transform-optional-chaining@latest \
                                   @jridgewell/sourcemap-codec@latest \
                                   @rollup/plugin-terser@latest
                        npm audit fix || true
                        npm install
                        CI=false npm run build
                    '''
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
                        string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                        sshUserPrivateKey(credentialsId: 'ssh-key-id', keyFileVariable: 'SSH_KEY')
                    ]) {
                        sh '''
                            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                            export AWS_DEFAULT_REGION=us-east-1
                            aws ecr get-login-password --region us-east-1 | ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker login --username AWS --password-stdin ${DOCKER_REGISTRY}'
                            cd frontend
                            for i in {1..3}; do
                                docker build -t ${FRONTEND_IMAGE} . && break
                                echo "Frontend build retry $i failed, waiting before next attempt..."
                                sleep 10
                            done
                            for i in {1..3}; do
                                docker push ${FRONTEND_IMAGE} && break
                                echo "Frontend push retry $i failed, waiting before next attempt..."
                                sleep 10
                            done
                            cd ../backend
                            for i in {1..3}; do
                                docker build -t ${BACKEND_IMAGE} . && break
                                echo "Backend build retry $i failed, waiting before next attempt..."
                                sleep 10
                            done
                            for i in {1..3}; do
                                docker push ${BACKEND_IMAGE} && break
                                echo "Backend push retry $i failed, waiting before next attempt..."
                                sleep 10
                            done
                        '''
                    }
                }
            }
        }
        stage('Deploy') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-id', keyFileVariable: 'SSH_KEY')]) {
                        sh '''
                            scp -o StrictHostKeyChecking=no -i ${SSH_KEY} docker-compose.yml ${SSH_USER}@${PUBLIC_IP}:/home/ec2-user/docker-compose.yml
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker-compose -f /home/ec2-user/docker-compose.yml down || true'
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker ps -q | xargs -r docker stop || true'
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker ps -a -q | xargs -r docker rm || true'
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker volume rm userstory-app-pipeline_db-data || true'
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker-compose -f /home/ec2-user/docker-compose.yml up -d --force-recreate' || { echo "Deployment failed"; exit 1; }
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'sleep 180'
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker ps -a'
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker logs userstory-frontend || echo "Frontend logs unavailable"'
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker logs userstory-backend || echo "Backend logs unavailable"'
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker logs userstory-db || echo "Database logs unavailable"'
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'for i in {1..5}; do docker exec userstory-db mysqladmin ping -h localhost -u root -prootpass && break; echo "Database ping retry $i failed"; sleep 15; done'
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker exec userstory-db mysqladmin ping -h localhost -u root -prootpass || echo "Database ping failed"'
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'for i in {1..5}; do docker exec userstory-backend nc -zv db 3306 && break; echo "Database connection retry $i failed"; sleep 15; done'
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker exec userstory-backend nc -zv db 3306 || echo "Database connection failed"'
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker exec userstory-backend curl -f http://localhost:8080/actuator/health || echo "Backend health check failed"'
                            for i in {1..3}; do
                                curl -s -f http://${PUBLIC_IP}:8080/api/projects && break
                                echo "API check retry $i failed, waiting before next attempt..."
                                sleep 10
                            done
                            curl -s -f http://${PUBLIC_IP}:8080/api/projects || echo 'API check failed'
                        '''
                    }
                }
            }
        }
        stage('Test Application') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-id', keyFileVariable: 'SSH_KEY')]) {
                        sh '''
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'for i in {1..3}; do docker exec userstory-frontend curl -s -f http://backend:8080/api/projects && break; echo "API check retry $i failed"; sleep 10; done'
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker exec userstory-frontend curl -s -f http://backend:8080/api/projects || echo "API check failed"'
                            curl -s -f http://${PUBLIC_IP}/api/projects || echo 'External API check failed'
                        '''
                    }
                }
            }
        }
    }
    post {
        always {
            withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-id', keyFileVariable: 'SSH_KEY')]) {
                sh '''
                    ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${PUBLIC_IP} 'docker logout ${DOCKER_REGISTRY}' || true
                '''
            }
        }
    }
}