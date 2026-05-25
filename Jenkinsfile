pipeline {
    agent any

    environment {
        APP_NAME = 'responsive-website'
        APP_VERSION = "${BUILD_NUMBER}"

        SONAR_HOST_URL = 'http://192.168.0.8:30474'
        SONAR_LOGIN = credentials('sonarqube-token')
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
                    echo "Current Directory: $(pwd)"

                    echo ""
                    echo "Workspace Contents:"
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
                    java -version 2>&1 || echo "Java not found"

                    echo ""
                    echo "Gradle Wrapper Check:"
                    ls -l gradlew || echo "gradlew not found"
                '''
            }
        }

        stage('Build') {
            steps {
                echo "========== Building Application =========="

                sh '''
                    if [ ! -f gradlew ]; then
                        echo "ERROR: gradlew file not found"
                        exit 1
                    fi

                    chmod +x gradlew

                    ./gradlew --version

                    echo ""
                    echo "Starting Gradle Build..."

                    ./gradlew clean build -x test --info
                '''
            }
        }

        stage('Verify Build Output') {
            steps {
                echo "========== Verifying Build Output =========="

                sh '''
                    if [ ! -d build/libs ]; then
                        echo "ERROR: build/libs directory not found"
                        exit 1
                    fi

                    echo "Artifacts Found:"
                    ls -lh build/libs/

                    JAR_FILE=$(find build/libs -name "*.jar" \
                        -not -name "*-plain.jar" \
                        -not -name "*-sources.jar" | head -1)

                    if [ -z "$JAR_FILE" ]; then
                        echo "ERROR: No JAR artifact found"
                        exit 1
                    fi

                    echo ""
                    echo "Selected Artifact:"
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
                        -Dsonar.login=${SONAR_LOGIN} \
                    || echo "SonarQube analysis failed, continuing..."
                '''
            }
        }

        stage('Publish to Nexus') {
            steps {
                echo "========== Publishing Artifact to Nexus =========="

                sh '''
                    JAR_FILE=$(find build/libs -name "*.jar" \
                        -not -name "*-plain.jar" \
                        -not -name "*-sources.jar" | head -1)

                    if [ -z "$JAR_FILE" ]; then
                        echo "ERROR: No JAR file found"
                        exit 1
                    fi

                    ARTIFACT_NAME=$(basename "$JAR_FILE")

                    echo "Uploading Artifact:"
                    echo "$ARTIFACT_NAME"

                    curl -v -u ${NEXUS_CREDS_USR}:${NEXUS_CREDS_PSW} \
                        --upload-file "$JAR_FILE" \
                        "${NEXUS_URL}/repository/${NEXUS_REPOSITORY}/${APP_NAME}/${APP_VERSION}/${ARTIFACT_NAME}"
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "========== Docker Build & Push =========="

                sh '''
                    echo "Building Docker Image..."

                    docker build -t ${APP_NAME}:${APP_VERSION} .

                    echo ""
                    echo "Tagging Image..."

                    docker tag ${APP_NAME}:${APP_VERSION} \
                        ${NEXUS_DOCKER_REPO}/${APP_NAME}:${APP_VERSION}

                    docker tag ${APP_NAME}:${APP_VERSION} \
                        ${NEXUS_DOCKER_REPO}/${APP_NAME}:latest

                    echo ""
                    echo "Docker Login..."

                    echo "${NEXUS_CREDS_PSW}" | docker login \
                        -u ${NEXUS_CREDS_USR} \
                        --password-stdin \
                        ${NEXUS_DOCKER_REPO}

                    echo ""
                    echo "Pushing Images..."

                    docker push ${NEXUS_DOCKER_REPO}/${APP_NAME}:${APP_VERSION}

                    docker push ${NEXUS_DOCKER_REPO}/${APP_NAME}:latest

                    echo ""
                    echo "Docker Push Successful"
                '''
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                echo "========== Kubernetes Deployment =========="

                sh '''
                    kubectl create namespace ${K8S_NAMESPACE} \
                        --dry-run=client -o yaml | kubectl apply -f -

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

        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"

          limits:
            memory: "512Mi"
            cpu: "500m"
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

                    echo ""
                    echo "Applying Kubernetes Resources..."

                    kubectl apply -f deployment.yaml

                    echo ""
                    echo "Waiting for Rollout..."

                    kubectl rollout status deployment/responsive-website \
                        -n ${K8S_NAMESPACE} \
                        --timeout=5m
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                echo "========== Deployment Verification =========="

                sh '''
                    echo "Pods:"
                    kubectl get pods -n ${K8S_NAMESPACE}

                    echo ""
                    echo "Services:"
                    kubectl get svc -n ${K8S_NAMESPACE}

                    echo ""
                    echo "Deployment:"
                    kubectl get deployment -n ${K8S_NAMESPACE}

                    echo ""
                    echo "Application URL:"
                    echo "http://192.168.0.6:30080"
                '''
            }
        }
    }

    post {

        success {
            echo "========== PIPELINE SUCCESS =========="
            echo "Application deployed successfully"
            echo "URL: http://192.168.0.6:30080"
        }

        failure {
            echo "========== PIPELINE FAILED =========="
            echo "Check console logs for exact error"
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
