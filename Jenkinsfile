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
                    echo "Workspace Contents:"
                    ls -la
                    echo ""
                    echo "System Info:"
                    docker version | head -5
                    kubectl version --client --short
                    git --version
                    java -version 2>&1 || echo "Java not found in PATH"
                '''
            }
        }

        stage('Build') {
            steps {
                echo "========== Building JAR =========="
                sh '''
                    chmod +x gradlew
                    ./gradlew --version
                    echo ""
                    echo "Starting gradle build..."
                    ./gradlew clean build -x test --info 2>&1 | tail -50
                '''
            }
        }

        stage('Verify Build Output') {
            steps {
                echo "========== Checking Build Output =========="
                sh '''
                    echo "Checking build/libs directory:"
                    if [ -d build/libs ]; then
                        ls -lh build/libs/
                    else
                        echo "ERROR: build/libs directory not found!"
                        exit 1
                    fi
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                echo "========== SonarQube Scan =========="
                sh '''
                    ./gradlew sonarqube \
                        -Dsonar.projectKey=${SONARQUBE_PROJECT_KEY} \
                        -Dsonar.projectName="${SONARQUBE_PROJECT_NAME}" \
                        -Dsonar.sources=src \
                        -Dsonar.host.url=${SONAR_HOST_URL} \
                        -Dsonar.login=${SONAR_LOGIN} || echo "SonarQube scan warning - continuing"
                '''
            }
        }

        stage('Publish to Nexus') {
            steps {
                echo "========== Upload to Nexus =========="
                sh '''
                    JAR_FILE=$(find build/libs -name "*.jar" -not -name "*-sources.jar" -not -name "*-plain.jar" | head -1)
                    
                    if [ -z "$JAR_FILE" ]; then
                        echo "ERROR: No JAR file found in build/libs"
                        ls -lh build/libs/
                        exit 1
                    fi
                    
                    ARTIFACT_NAME=$(basename "$JAR_FILE")
                    echo "Found JAR: $ARTIFACT_NAME"
                    
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
                    echo "Building Docker image..."
                    docker build -t ${APP_NAME}:${APP_VERSION} .
                    
                    echo "Tagging for Nexus registry..."
                    docker tag ${APP_NAME}:${APP_VERSION} ${NEXUS_DOCKER_REPO}/${APP_NAME}:${APP_VERSION}
                    docker tag ${APP_NAME}:${APP_VERSION} ${NEXUS_DOCKER_REPO}/${APP_NAME}:latest
                    
                    echo "Logging into Nexus Docker registry..."
                    echo "${NEXUS_CREDS_PSW}" | docker login -u ${NEXUS_CREDS_USR} --password-stdin ${NEXUS_DOCKER_REPO}
                    
                    echo "Pushing image..."
                    docker push ${NEXUS_DOCKER_REPO}/${APP_NAME}:${APP_VERSION}
                    docker push ${NEXUS_DOCKER_REPO}/${APP_NAME}:latest
                    
                    echo "Docker image pushed successfully"
                '''
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                echo "========== K8s Deployment =========="
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
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /actuator/health
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
                echo "========== Deployment Status =========="
                sh '''
                    echo "Pods in ${K8S_NAMESPACE}:"
                    kubectl get pods -n ${K8S_NAMESPACE}
                    echo ""
                    echo "Services in ${K8S_NAMESPACE}:"
                    kubectl get svc -n ${K8S_NAMESPACE}
                    echo ""
                    echo "✓ Application accessible at: http://192.168.0.6:30080"
                '''
            }
        }
    }

    post {
        success {
            echo "✓ ========== PIPELINE SUCCESS =========="
            echo "✓ Application deployed at: http://192.168.0.6:30080"
        }
        failure {
            echo "✗ ========== PIPELINE FAILED =========="
            echo "✗ Check the logs above for specific error details"
        }
        always {
            echo "========== Build Summary =========="
            sh '''
                echo "Build Number: ${BUILD_NUMBER}"
                echo "Build Status: $([ $? -eq 0 ] && echo 'SUCCESS' || echo 'FAILURE')"
            '''
        }
    }
}
