pipeline {
    agent any

    environment {
        GIT_REPO = 'https://github.com/sravan-0303/my-responsive-website.git'
        GIT_BRANCH = 'main'

        APP_NAME = 'responsive-website'
        APP_VERSION = "${BUILD_NUMBER}"

        SONAR_HOST_URL = 'http://192.168.0.8:30474'
        SONAR_LOGIN = credentials('sonarqube-token')
        SONARQUBE_PROJECT_KEY = 'responsive-website'
        SONARQUBE_PROJECT_NAME = 'Responsive Website'

        NEXUS_URL = 'http://192.168.0.8:30081'
        NEXUS_REPOSITORY = 'java-releases'
        NEXUS_CREDS = credentials('nexus-creds')

        DOCKER_IMAGE_NAME = 'responsive-website'
        DOCKER_IMAGE_TAG = "${BUILD_NUMBER}"
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
                sh '''
                    echo "Workspace: $WORKSPACE"
                    docker --version
                    kubectl version --client
                    git --version
                '''
            }
        }

        stage('Git Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build JAR') {
            steps {
                sh '''
                    echo "Building JAR file..."
                    chmod +x gradlew
                    ./gradlew clean build -x test
                    
                    JAR_FILE=$(find build/libs -name "*.jar" | head -1)
                    if [ -z "$JAR_FILE" ]; then
                        echo "ERROR: No JAR file found in build/libs"
                        exit 1
                    fi
                    
                    echo "JAR File Built: $JAR_FILE"
                    ls -lh "$JAR_FILE"
                '''
            }
        }

        stage('SonarQube Scan') {
            steps {
                sh '''
                    echo "Running SonarQube analysis..."
                    ./gradlew sonarqube \
                        -Dsonar.projectKey=${SONARQUBE_PROJECT_KEY} \
                        -Dsonar.projectName="${SONARQUBE_PROJECT_NAME}" \
                        -Dsonar.sources=src \
                        -Dsonar.host.url=${SONAR_HOST_URL} \
                        -Dsonar.login=${SONAR_LOGIN}
                '''
            }
        }

        stage('Push to Nexus') {
            steps {
                sh '''
                    echo "Pushing artifact to Nexus..."
                    
                    JAR_FILE=$(find build/libs -name "*.jar" | head -1)
                    ARTIFACT_NAME=$(basename "$JAR_FILE")
                    
                    curl -v -u ${NEXUS_CREDS_USR}:${NEXUS_CREDS_PSW} \
                        --upload-file "$JAR_FILE" \
                        "${NEXUS_URL}/repository/${NEXUS_REPOSITORY}/${APP_NAME}/${APP_VERSION}/${ARTIFACT_NAME}"
                    
                    echo "Artifact uploaded to Nexus"
                '''
            }
        }

        stage('Docker Build & Push') {
            steps {
                sh '''
                    echo "Building Docker image..."
                    
                    docker build -t ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} .
                    docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ${DOCKER_IMAGE_NAME}:latest
                    
                    # Tag for Nexus registry
                    docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                        ${NEXUS_DOCKER_REPO}/${APP_NAME}:${DOCKER_IMAGE_TAG}
                    docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                        ${NEXUS_DOCKER_REPO}/${APP_NAME}:latest
                    
                    # Login and push
                    echo "${NEXUS_CREDS_PSW}" | docker login -u ${NEXUS_CREDS_USR} --password-stdin ${NEXUS_DOCKER_REPO}
                    
                    docker push ${NEXUS_DOCKER_REPO}/${APP_NAME}:${DOCKER_IMAGE_TAG}
                    docker push ${NEXUS_DOCKER_REPO}/${APP_NAME}:latest
                    
                    echo "Docker image pushed to Nexus"
                '''
            }
        }

        stage('Kubernetes Deploy') {
            steps {
                sh '''
                    kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                    
                    cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: responsive-website
  namespace: production
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
      - name: app
        image: 192.168.0.8:30082/responsive-website:latest
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
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: responsive-website-service
  namespace: production
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
                    kubectl rollout status deployment/responsive-website -n ${K8S_NAMESPACE} --timeout=5m
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    echo "Deployment Status:"
                    kubectl get pods -n ${K8S_NAMESPACE}
                    kubectl get svc -n ${K8S_NAMESPACE}
                '''
            }
        }
    }

    post {
        success {
            echo "✓ Pipeline Success - Deployment Complete"
        }
        failure {
            echo "✗ Pipeline Failed - Check logs"
        }
        always {
            cleanWs()
        }
    }
}
