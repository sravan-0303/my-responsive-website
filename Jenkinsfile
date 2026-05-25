pipeline {
    agent any

    environment {
        SONAR_HOST_URL = 'http://192.168.0.8:30474'
        SONAR_TOKEN = credentials('sonar-token')
    }

    stages {

        stage('Pre-Check') {
            steps {

                echo '========== PRECHECK =========='

                sh '''
                    echo "Current Directory:"
                    pwd

                    echo ""
                    echo "Workspace Files:"
                    ls -la

                    echo ""
                    echo "Git Version:"
                    git --version

                    echo ""
                    echo "Java Version:"
                    java -version || true
                '''
            }
        }

        stage('Build') {
            steps {

                echo '========== BUILD =========='

                sh '''
                    chmod +x gradlew || true

                    ./gradlew clean build -x test
                '''
            }
        }

        stage('Verify Artifact') {
            steps {

                echo '========== VERIFY ARTIFACT =========='

                sh '''
                    echo "Artifacts Generated:"
                    ls -lh build/libs/

                    echo ""
                    echo "JAR Files:"
                    find build/libs -name "*.jar"
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {

                echo '========== SONARQUBE ANALYSIS =========='

                sh '''
                    ./gradlew sonarqube \
                        -Dsonar.host.url=${SONAR_HOST_URL} \
                        -Dsonar.login=${SONAR_TOKEN} \
                    || true
                '''
            }
        }
    }

    post {

        success {
            echo '========== PIPELINE SUCCESS =========='
        }

        failure {
            echo '========== PIPELINE FAILED =========='
        }

        always {

            echo '========== BUILD SUMMARY =========='

            sh '''
                echo "Build Number: ${BUILD_NUMBER}"
                echo "Job Name: ${JOB_NAME}"
                echo "Workspace: ${WORKSPACE}"
            '''
        }
    }
}
