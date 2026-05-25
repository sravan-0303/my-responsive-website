pipeline {
    agent any

    environment {
        APP_NAME = 'responsive-website'
        APP_VERSION = '1.0'
    }

    stages {

        stage('Pre-Check') {
            steps {

                echo '========== PRECHECK =========='

                sh '''
                    echo "Workspace:"
                    pwd

                    echo ""
                    echo "Files:"
                    ls -la

                    echo ""
                    echo "Git:"
                    git --version

                    echo ""
                    echo "Java:"
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

                echo '========== VERIFY =========='

                sh '''
                    ls -lh build/libs || true
                '''
            }
        }
    }

    post {

        success {
            echo '========== SUCCESS =========='
        }

        failure {
            echo '========== FAILED =========='
        }

        always {

            echo '========== SUMMARY =========='

            sh '''
                echo "Build Number: ${BUILD_NUMBER}"
                echo "Job Name: ${JOB_NAME}"
            '''
        }
    }
}
