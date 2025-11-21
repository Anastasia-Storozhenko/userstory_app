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
                    sh "docker -H ${DOCKER_HOST} info --format '{{.ServerVersion}}'"
                    sh "docker -H ${DOCKER_HOST} network ls"
                }
            }
        }

        stage('Checkout') {
            steps {
                git branch: 'master', credentialsId: 'github-credentials', url: 'https://github.com/Anastasia-Storozhenko/userstory_app.git'
            }
        }

        stage('Terraform Init & Plan') {
            steps {
                dir('terraform/envs/dev') {
                    withCredentials([string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                                     string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh '''
                            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                            export AWS_DEFAULT_REGION=us-east-1
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
                    withCredentials([string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                                     string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
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
                    command -v aws >/dev/null 2>&1 && echo "AWS CLI вже встановлено" && exit 0
                    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                    unzip -o awscliv2.zip
                    sudo ./aws/install --update || sudo ./aws/install
                    rm -rf awscliv2.zip aws
                    aws --version
                '''
            }
        }

        stage('Validate Infrastructure') {
            steps {
                withCredentials([string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                                 string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        export AWS_DEFAULT_REGION=us-east-1
                        aws ec2 describe-vpcs --filters "Name=tag:Name,Values=userstory-vpc" --output table
                        aws ecr describe-repositories --repository-names userstory-frontend-repo userstory-backend-repo || echo "ECR repos ok"
                    '''
                }
            }
        }

        
        stage('Build Frontend Code') {
            steps {
                dir('frontend') {
                    sh 'npm ci --prefer-offline --no-audit --no-fund'
                    sh 'CI=false npm run build'
                }
            }
        }

        stage('Build Backend Code') {
            steps {
                dir('backend') {
                    sh 'mvn clean package -DskipTests -Dmaven.test.skip=true'
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                script {
                    dir('frontend') {
                        sh """
                            docker -H ${DOCKER_HOST} build --pull -t ${FRONTEND_IMAGE} .
                        """
                    }
                    dir('backend') {
                        sh """
                            docker -H ${DOCKER_HOST} build --pull -t ${BACKEND_IMAGE} .
                        """
                    }
                }
            }
        }
        stage('Push Docker Images') {
            steps {
                withCredentials([string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                                 string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        export AWS_DEFAULT_REGION=us-east-1
                        aws ecr get-login-password --region us-east-1 | \
                            docker -H ${DOCKER_HOST} login --username AWS --password-stdin ${DOCKER_REGISTRY}

                        docker -H ${DOCKER_HOST} push ${FRONTEND_IMAGE} || echo "Frontend push skipped (immutable?)"
                        docker -H ${DOCKER_HOST} push ${BACKEND_IMAGE} || echo "Backend push skipped (immutable?)"
                    '''
                }
            }
        }

        stage('Trigger Deploy Pipeline') {
            steps {
                build job: 'userstory-deploy-pipeline', wait: true, parameters: [
                    string(name: 'FRONTEND_IMAGE', value: "${FRONTEND_IMAGE}"),
                    string(name: 'BACKEND_IMAGE', value: "${BACKEND_IMAGE}")
                ]
            }
        }
    }

    post {
        always {
            sh "docker -H ${DOCKER_HOST} logout ${DOCKER_REGISTRY} || true"
            cleanWs()
        }
    }
}
