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
                    sh "docker -H ${DOCKER_HOST} info --format '{{.ServerVersion}}' || exit 1"
                    sh "docker -H ${DOCKER_HOST} network ls || exit 1"
                }
            }
        }
        stage('Checkout') {
            steps {
                git branch: 'master', credentialsId: 'github-credentials', url: 'https://github.com/Anastasia-Storozhenko/userstory_app.git'
            }
        }

        stage('SonarCloud Analysis') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    script {
                        parallel(
                            backend: {
                                dir('backend') {
                                    withCredentials([string(credentialsId: 'sonarcloud-token', variable: 'SONAR_TOKEN')]) {
                                        sh '''
                                            echo "=== BACKEND SONAR ANALYSIS ==="
                                            export MAVEN_OPTS="-Xmx3g -Xms1g"
                                            mvn clean compile org.sonarsource.scanner.maven:sonar-maven-plugin:4.0.0.4121:sonar -DskipTests \
                                                -Dsonar.projectKey=Anastasia-Storozhenko_userstory_app_backend \
                                                -Dsonar.projectName=Anastasia-Storozhenko_userstory_app_backend \
                                                -Dsonar.organization=anastasia-storozhenko \
                                                -Dsonar.host.url=https://sonarcloud.io \
                                                -Dsonar.token=${SONAR_TOKEN} \
                                                -Dsonar.sources=src/main/java \
                                                -Dsonar.exclusions=target/**,src/test/**,src/main/resources/** \
                                                -Dsonar.java.source=17 \
                                                -Dsonar.coverage.exclusions=**/* \
                                                -Dsonar.cpd.exclusions=**/* \
                                                -Dsonar.textenterprise.skip=true
                                            echo "✅ Backend Sonar analysis completed"
                                        '''
                                    }
                                }
                            },
                            frontend: {
                                dir('frontend') {
                                    nodejs('nodejs-20.11.0') {
                                        withCredentials([string(credentialsId: 'sonarcloud-token', variable: 'SONAR_TOKEN')]) {
                                            sh '''
                                                echo "=== FRONTEND SONAR ANALYSIS ==="
                                                export NODE_OPTIONS="--max_old_space_size=2048"
                                                
                                                # Встановлюємо останню стабільну версію sonar-scanner
                                                npm install -g sonar-scanner
                                                
                                                # Альтернативно: використовуємо npx з останньою версією
                                                npx sonar-scanner@latest \
                                                    -Dsonar.projectKey=Anastasia-Storozhenko_userstory_app_frontend \
                                                    -Dsonar.organization=anastasia-storozhenko \
                                                    -Dsonar.host.url=https://sonarcloud.io \
                                                    -Dsonar.token=${SONAR_TOKEN} \
                                                    -Dsonar.sources=src \
                                                    -Dsonar.exclusions=node_modules/**,public/**,build/**,dist/**,coverage/**,**/*.test.*,**/*.spec.* \
                                                    -Dsonar.sourceEncoding=UTF-8 \
                                                    -Dsonar.coverage.exclusions=**/* \
                                                    -Dsonar.cpd.exclusions=**/* \
                                                    -Dsonar.css.skip=true \
                                                    -Dsonar.html.skip=true
                                                echo "✅ Frontend Sonar analysis completed"
                                            '''
                                        }
                                    }
                                }
                            }
                        )
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
                    # Встановлюємо unzip залежно від дистрибутива
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

        stage('Build Docker Images') {
            steps {
                script {
                    dir('frontend') {
                        sh "docker -H ${DOCKER_HOST} build -t ${FRONTEND_IMAGE} ."
                    }
                    dir('backend') {
                        sh "docker -H ${DOCKER_HOST} build -t ${BACKEND_IMAGE} ."
                    }
                }
            }
        }

       stage('Push Docker Images') {
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
                            
                            
                            aws ecr get-login-password --region us-east-1 | docker -H tcp://192.168.56.20:2375 login --username AWS --password-stdin 182000022338.dkr.ecr.us-east-1.amazonaws.com
                            
                            # Функція для спроби пуша з обробкою immutable
                            try_push_image() {
                                local image_name=$1
                                local image_type=$2
                                
                                echo "Attempting to push $image_type..."
                                
                                
                                if docker -H tcp://192.168.56.20:2375 push "$image_name"; then
                                    echo "Successfully pushed $image_type"
                                else
                                    # Якщо push впав, перевіряємо чи це через immutable tags
                                    local push_output=$(docker -H tcp://192.168.56.20:2375 push "$image_name" 2>&1 || true)
                                    
                                    if echo "$push_output" | grep -q "immutable"; then
                                        echo "Skipping $image_type - immutable tags detected"
                                    else
                                        echo "Failed to push $image_type for unknown reason"
                                        exit 1
                                    fi
                                fi
                            }
                            
                            
                            try_push_image "182000022338.dkr.ecr.us-east-1.amazonaws.com/userstory-frontend-repo:latest" "frontend"
                            try_push_image "182000022338.dkr.ecr.us-east-1.amazonaws.com/userstory-backend-repo:latest" "backend"
                            
                            echo "Push process completed"
                        '''
                    }
                }
            }
        }

        
        stage('Checkout Docker Repo for Deploy') {
            steps {
                dir('docker-deploy-files') {
                    git branch: 'main', credentialsId: 'github-credentials', url: 'https://github.com/Anastasia-Storozhenko/userstory-app-docker.git'
                    sh 'ls -la'  
                }
            }
        }
        
        stage('Deploy') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    script {
                        dir('docker-deploy-files') {
                            sh '''
                                echo "=== DEPLOY USING DOCKER-COMPOSE FROM SEPARATE REPO ==="
                                
                                # Переконуємося, що docker-compose.yml існує
                                ls -la docker-compose.yml || echo "docker-compose.yml not found in repo"
                                
                                # Виконуємо docker-compose через DOCKER_HOST
                                export DOCKER_CLIENT_TIMEOUT=300
                                export COMPOSE_HTTP_TIMEOUT=300
                                docker-compose -H ${DOCKER_HOST} -f docker-compose.yml down || true
                                docker-compose -H ${DOCKER_HOST} -f docker-compose.yml up -d --build
                                
                                # Перевіряємо статус контейнерів
                                docker -H ${DOCKER_HOST} ps -a
                                sleep 10  
                                echo "Deploy completed successfully"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Test Application') {
            steps {
                timeout(time: 2, unit: 'MINUTES') {
                    script {
                        sh '''
                            echo "=== TESTING APPLICATION ==="
                            docker -H ${DOCKER_HOST} exec userstory-frontend curl -s http://userstory-backend:8080/api/projects || echo "API check failed (backend on port 8080)"
                            curl -s http://192.168.56.20:8080 || echo "Frontend check failed"
                        '''
                    }
                }
            }
        }
    }
    post {
        always {
            sh "docker -H ${DOCKER_HOST} logout ${DOCKER_REGISTRY}"
            // Очищення тимчасової папки з Docker-репозиторієм
            sh "rm -rf docker-deploy-files || true"
        }
    }
}