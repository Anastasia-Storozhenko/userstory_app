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
        
        stage('Debug Terraform State') {
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
                            
                            terraform init
                            echo "=== Terraform State List ==="
                            terraform state list || echo "State is empty"
                            echo "=== Terraform Plan Output ==="
                            terraform plan -detailed-exitcode -var="project_prefix=${TF_VAR_project_prefix}" -var="env_name=${TF_VAR_env_name}" || echo "Plan completed with changes"
                        '''
                    }
                }
            }
        }

        stage('Clean State if Needed') {
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
                            
                            terraform init
                            # Check if key resources exist in AWS
                            echo "=== Checking real AWS resources before cleaning state ==="
                            VPC_EXISTS=$(aws ec2 describe-vpcs --filters "Name=vpc-id,Values=vpc-0345483fc5285dae2" --query 'Vpcs | length(@)' || echo 0)
                            FRONTEND_EXISTS=$(aws ec2 describe-instances --filters "Name=instance-id,Values=i-04fbb5a25cbee00d2" --query 'Reservations | length(@)' || echo 0)
                            echo "VPC exists: $VPC_EXISTS, Frontend EC2 exists: $FRONTEND_EXISTS"
                            
                            # Run plan and capture exit code
                            terraform plan -detailed-exitcode -var="project_prefix=${TF_VAR_project_prefix}" -var="env_name=${TF_VAR_env_name}" > plan_output.txt 2>&1
                            PLAN_EXIT_CODE=$?
                            echo "Terraform plan exit code: $PLAN_EXIT_CODE"
                            
                            if [ $PLAN_EXIT_CODE -eq 0 ] && [ $VPC_EXISTS -eq 0 ] && [ $FRONTEND_EXISTS -eq 0 ]; then
                                echo "No changes in plan and key resources not found in AWS - cleaning state"
                                rm -f terraform.tfstate terraform.tfstate.backup
                                terraform init
                            else
                                echo "Plan shows changes or resources exist (exit code: $PLAN_EXIT_CODE, VPC: $VPC_EXISTS, Frontend: $FRONTEND_EXISTS), proceeding without state cleanup"
                            fi
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
                            terraform plan -out=tfplan -var="project_prefix=${TF_VAR_project_prefix}" -var="env_name=${TF_VAR_env_name}" -detailed-exitcode
                            echo "Plan exit code: $?"
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
                            echo "=== Apply Summary ==="
                            terraform output || echo "No outputs defined"
                            echo "=== State After Apply ==="
                            terraform state list || echo "State is empty"
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
                        
                        echo "=== Current AWS Identity ==="
                        aws sts get-caller-identity
                        
                        echo "=== VPC Check ==="
                        aws ec2 describe-vpcs --filters "Name=vpc-id,Values=vpc-0345483fc5285dae2" --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value]' || echo "VPC not found"
                        
                        echo "=== EC2 Frontend Check ==="
                        aws ec2 describe-instances --filters "Name=instance-id,Values=i-04fbb5a25cbee00d2" --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value]' || echo "Frontend EC2 not found"
                        
                        echo "=== EC2 Database Check ==="
                        aws ec2 describe-instances --filters "Name=instance-id,Values=i-02719192509b55184" --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value]' || echo "Database EC2 not found"
                        
                        echo "=== ECR Repos Check ==="
                        aws ecr describe-repositories --repository-names userstory-frontend-repo userstory-backend-repo --query 'repositories[*].[repositoryName,registryId]' || echo "ECR repos not found"
                    '''
                }
            }
        }

        stage('Build Frontend') {
            steps {
                dir('frontend') {
                    sh '''
                        rm -rf node_modules package-lock.json
                        npm cache clean --force
                        npm install --verbose
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
                            
                            aws ecr get-login-password --region us-east-1 | docker -H ${DOCKER_HOST} login --username AWS --password-stdin ${DOCKER_REGISTRY}
                            
                            try_push_image() {
                                local image_name=$1
                                local image_type=$2
                                
                                echo "Attempting to push $image_type..."
                                
                                if docker -H ${DOCKER_HOST} push "$image_name"; then
                                    echo "Successfully pushed $image_type"
                                else
                                    local push_output=$(docker -H ${DOCKER_HOST} push "$image_name" 2>&1 || true)
                                    if echo "$push_output" | grep -q "immutable"; then
                                        echo "Skipping $image_type - immutable tags detected"
                                    else
                                        echo "Failed to push $image_type for unknown reason"
                                        exit 1
                                    fi
                                fi
                            }
                            
                            try_push_image "${FRONTEND_IMAGE}" "frontend"
                            try_push_image "${BACKEND_IMAGE}" "backend"
                            
                            echo "Push process completed"
                        '''
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    sh "docker-compose -H ${DOCKER_HOST} -f docker-compose.yml down || true"
                    sh "docker-compose -H ${DOCKER_HOST} -f docker-compose.yml up -d --force-recreate || true"
                    sh "sleep 180"
                    sh "docker -H ${DOCKER_HOST} ps -a || echo 'No containers running'"
                }
            }
        }

        stage('Test Application') {
            steps {
                script {
                    sh "docker -H ${DOCKER_HOST} exec userstory-frontend curl -s http://localhost/api/projects || echo 'API check failed'"
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