pipeline {
    agent any
    tools {
        nodejs 'NodeJS-20.11.0' // Вказуємо Node.js 20.11.0
        jdk 'JDK17' // Вказуємо Java 17
        maven 'Maven3.6.3' // Вказуємо Maven
    }
    environment {
        // Змінні для бази даних
        DB_USERSTORYPROJ_URL = 'jdbc:mariadb://192.168.56.20:3306/userstory'
        DB_USERSTORYPROJ_USER = credentials('db-credentials') // Логін
        DB_USERSTORYPROJ_PASSWORD = credentials('db-credentials') // Пароль
        // Docker Registry
        DOCKER_REGISTRY = 'docker.io'
        DOCKER_CREDENTIALS = credentials('docker-registry-credentials')
        // Назви образів
        FRONTEND_IMAGE = "${DOCKER_REGISTRY}/anastasia-storozhenko/userstory-frontend:latest"
        BACKEND_IMAGE = "${DOCKER_REGISTRY}/anastasia-storozhenko/userstory-backend:latest"
        // Docker Host
        DOCKER_HOST = 'tcp://192.168.56.20:2375'
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', credentialsId: 'github-credentials', url: 'https://github.com/Anastasia-Storozhenko/userstory_app.git'
            }
        }
        stage('Build Frontend') {
            steps {
                dir('userstory_front') {
                    sh 'npm install'
                    sh 'npm run build'
                }
            }
        }
        stage('Build Backend') {
            steps {
                dir('userstoryproj_back') {
                    sh 'mvn clean package -DskipTests'
                }
            }
        }
        stage('Build Docker Images') {
            steps {
                dir('userstory_front') {
                    sh "docker -H ${DOCKER_HOST} build -t ${FRONTEND_IMAGE} ."
                }
                dir('userstoryproj_back') {
                    sh "docker -H ${DOCKER_HOST} build -t ${BACKEND_IMAGE} ."
                }
            }
        }
        stage('Push Docker Images') {
            steps {
                sh "echo ${DOCKER_CREDENTIALS_PSW} | docker -H ${DOCKER_HOST} login -u ${DOCKER_CREDENTIALS_USR} --password-stdin ${DOCKER_REGISTRY}"
                sh "docker -H ${DOCKER_HOST} push ${FRONTEND_IMAGE}"
                sh "docker -H ${DOCKER_HOST} push ${BACKEND_IMAGE}"
            }
        }
        stage('Deploy') {
            steps {
                sh "docker -H ${DOCKER_HOST} compose -f docker-compose.yml up -d"
            }
        }
    }
    post {
        always {
            sh "docker -H ${DOCKER_HOST} logout ${DOCKER_REGISTRY}"
        }
    }
}