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
                            echo "Запуск аналізу SonarCloud..."

                            # Аналіз бекенду (Maven)
                            cd backend
                            mvn verify sonar:sonar \
                                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                -Dsonar.organization=${SONAR_ORG} \
                                -Dsonar.host.url=${SONAR_HOST_URL} \
                                -Dsonar.login=${SONAR_TOKEN} \
                                -Dsonar.java.binaries=target/classes \
                                -Dsonar.sources=src/main/java \
                                -Dsonar.tests=src/test/java \
                                -Dsonar.junit.reportPaths=target/surefire-reports \
                                -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml || echo "SonarCloud backend failed"

                            # Аналіз фронтенду (npm + sonar-scanner)
                            cd ../frontend
                            npm install
                            CI=false npm run build

                            # Встановлюємо sonar-scanner (якщо ще немає)
                            npm install --save-dev sonar-scanner

                            # Запускаємо сканер
                            npx sonar-scanner \
                                -Dsonar.projectKey=${SONAR_PROJECT_KEY}_frontend \
                                -Dsonar.organization=${SONAR_ORG} \
                                -Dsonar.host.url=${SONAR_HOST_URL} \
                                -Dsonar.login=${SONAR_TOKEN} \
                                -Dsonar.sources=src \
                                -Dsonar.tests=src \
                                -Dsonar.test.inclusions="**/*.test.js,**/*.test.jsx" \
                                -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info || echo "SonarCloud frontend failed"
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