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
        // ВИПРАВЛЕНО: Використовуємо Docker Hub username
        FRONTEND_IMAGE = "${DOCKER_REGISTRY}/anastasiia191006/userstory-frontend:latest"
        BACKEND_IMAGE = "${DOCKER_REGISTRY}/anastasiia191006/userstory-backend:latest"
        DOCKER_HOST = 'tcp://192.168.56.20:2375'
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: 'master', credentialsId: 'github-credentials', url: 'https://github.com/Anastasia-Storozhenko/userstory_app.git'
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
                    sh "docker-compose -H ${DOCKER_HOST} -f ./docker-compose.yml up -d"
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