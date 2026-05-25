pipeline {
    agent any

    environment {
        SONAR_HOST_URL = 'http://192.168.0.8:30474'
        SONAR_TOKEN = credentials('sonarqube-token')
    }

    stages {

        stage('Build') {
            steps {

                sh '''
                    chmod +x gradlew
                    ./gradlew clean build -x test
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {

                sh '''
                    ./gradlew sonarqube \
                    -Dsonar.host.url=${SONAR_HOST_URL} \
                    -Dsonar.login=${SONAR_TOKEN} \
                    || true
                '''
            }
        }

        stage('Verify') {
            steps {

                sh '''
                    ls -lh build/libs/
                '''
            }
        }
    }
}
