pipeline {
    agent any

    environment {
        // Correct repository reference
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
        NEXUS_DOCKER_REGISTRY = '192.168.0.8:30082'
        NEXUS_CREDS = credentials('nexus-creds')

        DOCKER_IMAGE_NAME = "${APP_NAME}"
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
                    docker --version || true
                    kubectl version --client || true
                    git --version
                '''
            }
        }

        stage('Git Checkout') {
            steps {
                // Using standard checkout
                checkout scm
            }
        }

        stage('Build WAR') {
            steps {
                sh '''
                    echo "Building WAR file..."
                    chmod +x gradlew
                    ./gradlew clean build -x test
                    
                    # Verify WAR was created
                    WAR_FILE=$(find build/libs -name "*.war" | head -1)
                    if [ -z "$WAR_FILE" ]; then
                        echo "ERROR: No WAR file found in build/libs"
                        ls -lh build/libs/
                        exit 1
                    fi
                    
                    echo "WAR File Built: $WAR_FILE"
                    ls -lh "$WAR_FILE"
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
                    
                    WAR_FILE=$(find build/libs -name "*.war" | head -1)
                    
                    if [ -z "$WAR_FILE" ]; then
                        echo "ERROR: No WAR file found"
                        exit 1
                    fi
                    
                    ARTIFACT_NAME=$(basename "$WAR_FILE")
                    
                    echo "Uploading: $ARTIFACT_NAME"
                    
                    curl -v -u ${NEXUS_CREDS_USR}:${NEXUS_CREDS_PSW} \
                        --upload-file "$WAR_FILE" \
                        "${NEXUS_URL}/repository/${NEXUS_REPOSITORY}/${APP_NAME}/${APP_VERSION}/${ARTIFACT_NAME}"
                    
                    echo "Upload complete"
                '''
            }
        }

        stage('Docker Build & Push') {
            steps {
                sh '''
                    echo "Building Docker image..."
                    
                    WAR_FILE=$(find build/libs -name "*.war" | head -1)
                    WAR_NAME=$(basename "$WAR_FILE")
                    
                    # Create Dockerfile
                    cat > Dockerfile <<'DOCKER_EOF'
FROM tomcat:9.0-jdk11

RUN rm -rf /usr/local/tomcat/webapps/ROOT

COPY build/libs/*.war /usr/local/tomcat/webapps/ROOT.war

EXPOSE 8080

CMD ["catalina.sh","run"]
DOCKER_EOF
                    
                    # Build image
                    docker build -t ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} .
                    docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ${DOCKER_IMAGE_NAME}:latest
                    
                    # Tag for Nexus registry
                    docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                        ${NEXUS_DOCKER_REPO}/${APP_NAME}:${DOCKER_IMAGE_TAG}
                    docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                        ${NEXUS_DOCKER_REPO}/${APP_NAME}:latest
                    
                    # Login to Nexus Docker registry
                    echo "${NEXUS_CREDS_PSW}" | docker login -u ${NEXUS_CREDS_USR} --password-stdin ${NEXUS_DOCKER_REPO}
                    
                    # Push to Nexus
                    docker push ${NEXUS_DOCKER_REPO}/${APP_NAME}:${DOCKER_IMAGE_TAG}
                    docker push ${NEXUS_DOCKER_REPO}/${APP_NAME}:latest
                    
                    echo "Docker image pushed successfully"
                '''
            }
        }

        stage('Kubernetes Deploy') {
            steps {
                sh '''
                    echo "Deploying to Kubernetes..."
                    
                    # Create namespace if it doesn't exist
                    kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                    
                    # Create deployment manifest
                    cat > deployment.yaml <<'K8S_EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: responsive-website
  namespace: production
  labels:
    app: responsive-website
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
      - name: tomcat
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
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: responsive-website-service
  namespace: production
  labels:
    app: responsive-website
spec:
  type: NodePort
  selector:
    app: responsive-website
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
    nodePort: 30080
K8S_EOF
                    
                    # Apply deployment
                    kubectl apply -f deployment.yaml
                    
                    # Wait for rollout
                    kubectl rollout status deployment/responsive-website -n ${K8S_NAMESPACE} --timeout=5m
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    echo "Verifying deployment..."
                    kubectl get pods -n ${K8S_NAMESPACE}
                    kubectl get svc -n ${K8S_NAMESPACE}
                    kubectl describe deployment responsive-website -n ${K8S_NAMESPACE}
                '''
            }
        }
    }

    post {
        success {
            echo "✓ PIPELINE SUCCESS - Deployment Complete"
        }
        failure {
            echo "✗ PIPELINE FAILED - Check logs above"
        }
        always {
            cleanWs()
        }
    }
}
