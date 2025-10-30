pipeline {
    agent any
    tools {
        nodejs 'nodejs-20.11.0'
        jdk 'jdk17'
        maven 'maven-3.6.3'
    }
    environment {
        DB_USER = credentials('db-credentials')
        DB_USERSTORYPROJ_URL = 'jdbc:mariadb://192.168.56.20:3306/userstory'
        DB_USERSTORYPROJ_USER = "${DB_USER_USR}"
        DB_USERSTORYPROJ_PASSWORD = "${DB_USER_PSW}"
        DOCKER_REGISTRY = 'docker.io'
        DOCKER_CREDENTIALS = credentials('docker-registry-credentials')
        FRONTEND_IMAGE = "${DOCKER_REGISTRY}/anastasiia191006/userstory-frontend:latest"
        BACKEND_IMAGE = "${DOCKER_REGISTRY}/anastasiia191006/userstory-backend:latest"
        DOCKER_HOST = 'tcp://192.168.56.20:2375'
        COMPOSE_HTTP_TIMEOUT = '120'

        // SonarCloud
        SONAR_TOKEN = credentials('sonarcloud-token')
        SONAR_PROJECT_KEY = 'Anastasia-Storozhenko_userstory_app'
        SONAR_ORG = 'anastasia-storozhenko'
        SONAR_HOST_URL = 'https://sonarcloud.io'
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
                // SonarCloud Analysis
        stage('SonarCloud Analysis') {
            steps {
                script {
                    withCredentials([string(credentialsId: 'sonarcloud-token', variable: 'SONAR_TOKEN')]) {
                        sh '''
                            # Кешуємо node_modules
                            if [ ! -d "frontend/node_modules" ]; then
                                echo "Installing node_modules..."
                                cd frontend && npm ci
                            else
                                echo "Using cached node_modules"
                            fi

                            # Кешуємо sonar cache
                            export SONAR_USER_HOME=/var/lib/jenkins/.sonar
                            mkdir -p $SONAR_USER_HOME/cache

                            cd backend
                            mvn verify sonar:sonar \
                                -Dsonar.projectKey=Anastasia-Storozhenko_userstory_app_backend \
                                -Dsonar.organization=anastasia-storozhenko \
                                -Dsonar.host.url=https://sonarcloud.io \
                                -Dsonar.token=${SONAR_TOKEN} || true

                            cd ../frontend
                            CI=false npm run build

                            npm install --save-dev sonar-scanner

                            npx sonar-scanner \
                                -Dsonar.projectKey=Anastasia-Storozhenko_userstory_app_frontend \
                                -Dsonar.organization=anastasia-storozhenko \
                                -Dsonar.host.url=https://sonarcloud.io \
                                -Dsonar.token=${SONAR_TOKEN} \
                                -Dsonar.sources=src \
                                -Dsonar.exclusions="node_modules/**,public/**,build/**,**/*.test.js,**/*.test.jsx" \
                                -Dsonar.sourceEncoding=UTF-8 || true
                        '''
                    }
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
                    sh "docker -H ${DOCKER_HOST} build -t ${FRONTEND_IMAGE} ./frontend"
                    sh "docker -H ${DOCKER_HOST} build -t ${BACKEND_IMAGE} ./backend"
                }
            }
        }
        stage('Push Docker Images') {
            steps {
                script {
                    sh "echo ${DOCKER_CREDENTIALS_PSW} | docker -H ${DOCKER_HOST} login -u ${DOCKER_CREDENTIALS_USR} --password-stdin ${DOCKER_REGISTRY}"
                    sh "docker -H ${DOCKER_HOST} push ${FRONTEND_IMAGE}"
                    sh "docker -H ${DOCKER_HOST} push ${BACKEND_IMAGE}"
                }
            }
        }
        stage('Deploy') {
            steps {
                script {
                    sh "docker-compose -H ${DOCKER_HOST} -f ./docker-compose.yml down || true"
                    sh "docker-compose -H ${DOCKER_HOST} -f ./docker-compose.yml up -d --force-recreate || true"
                    sh "sleep 180"
                    sh "docker -H ${DOCKER_HOST} ps -a || echo 'No containers running'"
                    sh "docker -H ${DOCKER_HOST} inspect userstory-backend | grep Health || echo 'No backend health status'"
                    sh "docker -H ${DOCKER_HOST} inspect userstory-frontend | grep Health || echo 'No frontend health status'"
                }
            }
        }
        stage('Check Database Logs') {
            steps {
                script {
                    sh "docker -H ${DOCKER_HOST} logs userstory-db || echo 'No database logs available'"
                }
            }
        }
        stage('Check Backend Logs') {
            steps {
                script {
                    sh "docker -H ${DOCKER_HOST} logs userstory-backend || echo 'No backend logs available'"
                }
            }
        }
        stage('Check Database') {
            steps {
                script {
                    sh """
                    docker -H ${DOCKER_HOST} exec userstory-db mariadb -uuserstory_user -puserstory_pass userstory -e \
                    "SHOW TABLES; SELECT * FROM projects; SELECT 'Data count:', COUNT(*) FROM projects;" || echo 'Database check failed'
                    """
                }
            }
        }
        stage('Test Backend API') {
            steps {
                script {
                    sh """
                    docker -H ${DOCKER_HOST} run --rm --network userstory-app-pipeline_app-network curlimages/curl \
                    curl -s http://backend:8080/api/projects || echo 'API check failed'
                    """
                    sh """
                    docker -H ${DOCKER_HOST} run --rm --network userstory-app-pipeline_app-network curlimages/curl \
                    curl -s -X POST http://backend:8080/api/projects -H "Content-Type: application/json" -d '{"name":"Test2","description":"Test Description"}' || echo 'POST API check failed'
                    """
                    sh """
                    docker -H ${DOCKER_HOST} exec userstory-db mariadb -uuserstory_user -puserstory_pass userstory -e \
                    "SELECT * FROM projects WHERE name='Test2';" || echo 'Database check after POST failed'
                    """
                }
            }
        }
        stage('Test Frontend') {
            steps {
                script {
                    sh """
                    docker -H ${DOCKER_HOST} run --rm --network userstory-app-pipeline_app-network curlimages/curl \
                    curl -s http://frontend:80/api/projects || echo 'Frontend API check failed'
                    """
                    sh """
                    docker -H ${DOCKER_HOST} run --rm --network userstory-app-pipeline_app-network curlimages/curl \
                    curl -s http://192.168.56.20:80/api/projects || echo 'External frontend API check failed'
                    """
                    sh """
                    docker -H ${DOCKER_HOST} run --rm --network userstory-app-pipeline_app-network curlimages/curl \
                    curl -s http://192.168.56.20:80/projects || echo 'Frontend route check failed'
                    """
                }
            }
        }
        stage('Check Nginx Logs') {
            steps {
                script {
                    sh "docker -H ${DOCKER_HOST} logs userstory-frontend || echo 'No frontend logs available'"
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