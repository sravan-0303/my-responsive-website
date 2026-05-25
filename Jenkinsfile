pipeline {
    agent any

    environment {
        APP_NAME = 'responsive-website'
        APP_VERSION = "${env.BUILD_NUMBER}"

        SONAR_HOST_URL = 'http://192.168.0.8:30474'
        SONAR_TOKEN = credentials('sonarqube-token')

        SONARQUBE_PROJECT_KEY = 'responsive-website'
        SONARQUBE_PROJECT_NAME = 'Responsive Website'

        NEXUS_URL = 'http://192.168.0.8:30081'
        NEXUS_REPOSITORY = 'java-releases'

        NEXUS_CREDS = credentials('nexus-creds')

        NEXUS_DOCKER_REPO = '192.168.0.8:30082'

        K8S_NAMESPACE = 'production'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 60, unit: 'MINUTES')
        timestamps()
    }

    stages {

        stage('Pre-Check') {
            steps {

                echo "========== Environment Check =========="

                sh '''
                    echo "Current Directory:"
                    pwd

                    echo ""
                    echo "Workspace Files:"
                    ls -la

                    echo ""
                    echo "Docker Check:"
                    docker version || echo "Docker not available"

                    echo ""
                    echo "Kubectl Check:"
                    kubectl version --client || echo "Kubectl not available"

                    echo ""
                    echo "Git Check:"
                    git --version

                    echo ""
                    echo "Java Check:"
                    java -version || echo "Java not installed"

                    echo ""
                    echo "Gradle Wrapper Check:"
                    ls -l gradlew || echo "gradlew missing"
                '''
            }
        }

        stage('Build') {
            steps {

                echo "========== Build Stage =========="

                sh '''
                    if [ ! -f gradlew ]; then
                        echo "ERROR: gradlew not found"
                        exit 1
                    fi

                    chmod +x gradlew

                    ./gradlew clean build -x test
                '''
            }
        }

        stage('Verify Artifact') {
            steps {

                echo "========== Verify Artifact =========="

                sh '''
                    echo "Artifacts:"
                    ls -lh build/libs/

                    JAR_FILE=$(find build/libs -name "*.jar" | head -1)

                    if [ -z "$JAR_FILE" ]; then
                        echo "ERROR: No JAR file generated"
                        exit 1
                    fi

                    echo "Artifact Found:"
                    echo "$JAR_FILE"
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {

                echo "========== SonarQube Analysis =========="

                sh '''
                    chmod +x gradlew

                    ./gradlew sonarqube \
                        -Dsonar.projectKey=${SONARQUBE_PROJECT_KEY} \
                        -Dsonar.projectName="${SONARQUBE_PROJECT_NAME}" \
                        -Dsonar.sources=src \
                        -Dsonar.host.url=${SONAR_HOST_URL} \
                        -Dsonar.login=${SONAR_TOKEN} \
                    || echo "SonarQube analysis failed"
                '''
            }
        }

        stage('Upload to Nexus') {
            steps {

                echo "========== Upload to Nexus =========="

                sh '''
                    JAR_FILE=$(find build/libs -name "*.jar" | head -1)

                    if [ -z "$JAR_FILE" ]; then
                        echo "ERROR: JAR file missing"
                        exit 1
                    fi

                    ARTIFACT_NAME=$(basename "$JAR_FILE")

                    echo "Uploading:"
                    echo "$ARTIFACT_NAME"

                    curl -v \
                        -u ${NEXUS_CREDS_USR}:${NEXUS_CREDS_PSW} \
                        --upload-file "$JAR_FILE" \
                        "${NEXUS_URL}/repository/${NEXUS_REPOSITORY}/${APP_NAME}/${APP_VERSION}/${ARTIFACT_NAME}"
                '''
            }
        }

        stage('Docker Build & Push') {
            steps {

                echo "========== Docker Build =========="

                sh '''
                    docker build -t ${APP_NAME}:${APP_VERSION} .

                    docker tag ${APP_NAME}:${APP_VERSION} ${NEXUS_DOCKER_REPO}/${APP_NAME}:${APP_VERSION}

                    docker tag ${APP_NAME}:${APP_VERSION} ${NEXUS_DOCKER_REPO}/${APP_NAME}:latest

                    echo "${NEXUS_CREDS_PSW}" | docker login \
                        -u ${NEXUS_CREDS_USR} \
                        --password-stdin \
                        ${NEXUS_DOCKER_REPO}

                    docker push ${NEXUS_DOCKER_REPO}/${APP_NAME}:${APP_VERSION}

                    docker push ${NEXUS_DOCKER_REPO}/${APP_NAME}:latest
                '''
            }
        }

        stage('Deploy to Kubernetes') {
            steps {

                echo "========== Kubernetes Deployment =========="

                sh """
                    kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

                    cat > deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: responsive-website
  namespace: ${K8S_NAMESPACE}

spec:
  replicas: 2

  selector:
    matchLabels:
      app: responsive-website

  template:
    metadata:
      labels:
        app: responsive-website

    spec:
      imagePullSecrets:
      - name: nexus-registry-secret

      containers:
      - name: responsive-website

        image: ${NEXUS_DOCKER_REPO}/${APP_NAME}:latest

        imagePullPolicy: Always

        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service

metadata:
  name: responsive-website-service
  namespace: ${K8S_NAMESPACE}

spec:
  type: NodePort

  selector:
    app: responsive-website

  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
    nodePort: 30080
EOF

                    kubectl apply -f deployment.yaml

                    kubectl rollout status deployment/responsive-website \
                        -n ${K8S_NAMESPACE} \
                        --timeout=300s
                """
            }
        }

        stage('Verify Deployment') {
            steps {

                echo "========== Verify Deployment =========="

                sh '''
                    echo "Pods:"
                    kubectl get pods -n ${K8S_NAMESPACE}

                    echo ""
                    echo "Services:"
                    kubectl get svc -n ${K8S_NAMESPACE}

                    echo ""
                    echo "Deployment:"
                    kubectl get deployment -n ${K8S_NAMESPACE}
                '''
            }
        }
    }

    post {

        success {
            echo "========== PIPELINE SUCCESS =========="
            echo "Application URL: http://192.168.0.6:30080"
        }

        failure {
            echo "========== PIPELINE FAILED =========="
            echo "Check Console Output for exact error"
        }

        always {

            echo "========== BUILD SUMMARY =========="

            sh '''
                echo "Build Number: ${BUILD_NUMBER}"
                echo "Job Name: ${JOB_NAME}"
                echo "Workspace: ${WORKSPACE}"
            '''
        }
    }
}
