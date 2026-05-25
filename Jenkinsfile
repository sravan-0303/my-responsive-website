pipeline {
    agent any

    stages {

        stage('Pre-Check') {
            steps {
                echo 'PRECHECK'

                sh '''
                    pwd
                    ls -la
                    git --version
                    java -version || true
                '''
            }
        }

        stage('Build') {
            steps {
                echo 'BUILD STARTED'

                sh '''
                    chmod +x gradlew || true
                    ./gradlew clean build -x test
                '''
            }
        }

        stage('Verify') {
            steps {
                sh '''
                    echo "Artifacts:"
                    ls -lh build/libs/
                '''
            }
        }
    }
}

