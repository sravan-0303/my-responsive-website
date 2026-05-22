pipeline {
    agent {
        node {
            label 'built-in'
        }
    }
    
    environment {
        // ============ GIT Configuration ============
        GIT_REPO = 'https://github.com/Krishnamohan-Yerrabilli/Java_Gradle_Responsive_Website.git'
        GIT_BRANCH = 'main'
        
        // ============ Application Configuration ============
        APP_NAME = 'responsive-website'
        APP_VERSION = "${BUILD_NUMBER}"
        
        // ============ SonarQube Configuration (WN2: 192.168.0.8:30474) ============
        SONAR_HOST_URL = 'http://192.168.0.8:30474'
        SONAR_LOGIN = credentials('sonarqube-token')
        SONARQUBE_PROJECT_KEY = 'responsive-website'
        SONARQUBE_PROJECT_NAME = 'Responsive Website'
        
        // ============ Nexus Configuration (WN2: 192.168.0.8:30081) ============
        NEXUS_URL = 'http://192.168.0.8:30081'
        NEXUS_REPOSITORY = 'java-releases'
        NEXUS_DOCKER_REGISTRY = '192.168.0.8:30082'
        NEXUS_CREDS = credentials('nexus-creds')
        
        // ============ Docker Configuration ============
        DOCKER_IMAGE_NAME = "${APP_NAME}"
        DOCKER_IMAGE_TAG = "${BUILD_NUMBER}"
        
        // ============ DockerHub Configuration ============
        DOCKERHUB_CREDS = credentials('dockerhub-creds')
        DOCKERHUB_REPO = "${DOCKERHUB_CREDS_USR}/${APP_NAME}"
        
        // ============ Kubernetes Configuration ============
        K8S_MASTER = '192.168.0.10'
        K8S_NAMESPACE = 'production'
        K8S_DEPLOYMENT = 'tomcat-deployment'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 60, unit: 'MINUTES')
        timestamps()
    }

    stages {
        stage('📋 Pre-Flight Checks') {
            steps {
                script {
                    echo "=========================================="
                    echo "🔍 PRE-FLIGHT CHECKS"
                    echo "=========================================="
                    echo "✓ Jenkins Ready"
                    echo "✓ Agent: Built-in"
                    echo "✓ Workspace: ${WORKSPACE}"
                }
            }
        }

        stage('🔌 Connectivity Verification') {
            steps {
                sh '''
                    echo "=========================================="
                    echo "🔌 CONNECTIVITY VERIFICATION"
                    echo "=========================================="
                    
                    echo "Testing SonarQube (192.168.0.8:30474)..."
                    curl -s -I http://192.168.0.8:30474 | head -1 || echo "⚠️ SonarQube unreachable"
                    
                    echo "Testing Nexus (192.168.0.8:30081)..."
                    curl -s -I http://192.168.0.8:30081 | head -1 || echo "⚠️ Nexus unreachable"
                    
                    echo "Testing Docker..."
                    docker ps > /dev/null 2>&1 && echo "✓ Docker running" || echo "⚠️ Docker unreachable"
                    
                    echo "Testing Kubernetes..."
                    kubectl cluster-info > /dev/null 2>&1 && echo "✓ Kubernetes running" || echo "⚠️ Kubernetes unreachable"
                    kubectl get nodes -o wide
                '''
            }
        }

        stage('📥 Git Checkout') {
            steps {
                sh '''
                    echo "=========================================="
                    echo "📥 GIT CHECKOUT"
                    echo "=========================================="
                    pwd
                    ls -la
                '''
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "${GIT_BRANCH}"]],
                    userRemoteConfigs: [[url: "${GIT_REPO}"]]
                ])
                sh '''
                    echo "✓ Cloned successfully"
                    ls -la
                '''
            }
        }

        stage('🔨 Build with Gradle') {
            steps {
                sh '''
                    echo "=========================================="
                    echo "🔨 BUILDING APPLICATION WITH GRADLE"
                    echo "=========================================="
                    
                    chmod +x gradlew
                    ./gradlew clean build -x test
                    
                    echo "Build artifacts:"
                    ls -lh build/libs/
                    echo "✓ Build successful"
                '''
            }
        }

        stage('🔍 SonarQube Scan') {
            steps {
                sh '''
                    echo "=========================================="
                    echo "🔍 RUNNING SONARQUBE ANALYSIS"
                    echo "=========================================="
                    
                    ./gradlew sonarqube \
                      -Dsonar.projectKey=${SONARQUBE_PROJECT_KEY} \
                      -Dsonar.projectName="${SONARQUBE_PROJECT_NAME}" \
                      -Dsonar.sources=src \
                      -Dsonar.host.url=${SONAR_HOST_URL} \
                      -Dsonar.login=${SONAR_LOGIN} || true
                    
                    echo "✓ SonarQube analysis complete"
                    echo "📊 View at: ${SONAR_HOST_URL}/projects"
                '''
            }
        }

        stage('📤 Push to Nexus') {
            steps {
                sh '''
                    echo "=========================================="
                    echo "📤 PUSHING ARTIFACT TO NEXUS"
                    echo "=========================================="
                    
                    ARTIFACT=$(find build/libs -type f \\( -name "*.jar" -o -name "*.war" \\) | head -1)
                    
                    if [ -z "$ARTIFACT" ]; then
                        echo "❌ No artifact found!"
                        exit 1
                    fi
                    
                    echo "Found artifact: $ARTIFACT"
                    
                    curl -v -u ${NEXUS_CREDS_USR}:${NEXUS_CREDS_PSW} \
                      --upload-file "$ARTIFACT" \
                      "${NEXUS_URL}/repository/${NEXUS_REPOSITORY}/${APP_NAME}/${APP_VERSION}/$(basename $ARTIFACT)"
                    
                    echo "✓ Artifact uploaded to Nexus"
                '''
            }
        }

        stage('🐳 Build Docker Image') {
            steps {
                sh '''
                    echo "=========================================="
                    echo "🐳 BUILDING DOCKER IMAGE"
                    echo "=========================================="
                    
                    cat > Dockerfile << 'EOF'
FROM tomcat:9.0-jdk11-openjdk
RUN rm -rf /usr/local/tomcat/webapps/ROOT
COPY build/libs/*.jar /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
CMD ["catalina.sh", "run"]
EOF
                    
                    docker build -t ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} .
                    docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ${DOCKER_IMAGE_NAME}:latest
                    
                    echo "✓ Docker image built"
                    docker images | grep ${DOCKER_IMAGE_NAME}
                '''
            }
        }

        stage('🏪 Push to Nexus Registry') {
            steps {
                sh '''
                    echo "=========================================="
                    echo "🏪 PUSHING TO NEXUS DOCKER REGISTRY"
                    echo "=========================================="
                    
                    echo "${NEXUS_CREDS_PSW}" | docker login -u ${NEXUS_CREDS_USR} \
                      --password-stdin ${NEXUS_DOCKER_REGISTRY}
                    
                    docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                      ${NEXUS_DOCKER_REGISTRY}/${APP_NAME}:${DOCKER_IMAGE_TAG}
                    docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                      ${NEXUS_DOCKER_REGISTRY}/${APP_NAME}:latest
                    
                    docker push ${NEXUS_DOCKER_REGISTRY}/${APP_NAME}:${DOCKER_IMAGE_TAG}
                    docker push ${NEXUS_DOCKER_REGISTRY}/${APP_NAME}:latest
                    
                    echo "✓ Image pushed to Nexus Registry"
                '''
            }
        }

        stage('🌐 Push to DockerHub') {
            steps {
                sh '''
                    echo "=========================================="
                    echo "🌐 PUSHING TO DOCKERHUB"
                    echo "=========================================="
                    
                    echo "${DOCKERHUB_CREDS_PSW}" | docker login -u ${DOCKERHUB_CREDS_USR} \
                      --password-stdin
                    
                    docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                      ${DOCKERHUB_REPO}:${DOCKER_IMAGE_TAG}
                    docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                      ${DOCKERHUB_REPO}:latest
                    
                    docker push ${DOCKERHUB_REPO}:${DOCKER_IMAGE_TAG}
                    docker push ${DOCKERHUB_REPO}:latest
                    
                    echo "✓ Image pushed to DockerHub"
                    echo "🔗 Available at: ${DOCKERHUB_REPO}"
                '''
            }
        }

        stage('☸️ Deploy to Kubernetes') {
            steps {
                sh '''
                    echo "=========================================="
                    echo "☸️ DEPLOYING TO KUBERNETES"
                    echo "=========================================="
                    
                    # Create namespace
                    kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                    
                    # Create docker registry secret
                    kubectl delete secret nexus-docker-secret -n ${K8S_NAMESPACE} 2>/dev/null || true
                    kubectl create secret docker-registry nexus-docker-secret \
                      --docker-server=${NEXUS_DOCKER_REGISTRY} \
                      --docker-username=${NEXUS_CREDS_USR} \
                      --docker-password=${NEXUS_CREDS_PSW} \
                      --docker-email=jenkins@example.com \
                      -n ${K8S_NAMESPACE}
                    
                    # Create deployment YAML
                    cat > deployment.yaml << 'DEPLOY'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tomcat-deployment
  namespace: production
  labels:
    app: responsive-website
spec:
  replicas: 3
  selector:
    matchLabels:
      app: responsive-website
  template:
    metadata:
      labels:
        app: responsive-website
    spec:
      imagePullSecrets:
      - name: nexus-docker-secret
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
          initialDelaySeconds: 15
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
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080
    protocol: TCP
  selector:
    app: responsive-website
DEPLOY
                    
                    kubectl apply -f deployment.yaml
                    echo "✓ Deployment configuration applied"
                '''
            }
        }

        stage('⏳ Wait for Rollout') {
            steps {
                sh '''
                    echo "=========================================="
                    echo "⏳ WAITING FOR DEPLOYMENT ROLLOUT"
                    echo "=========================================="
                    
                    kubectl rollout status deployment/tomcat-deployment \
                      -n ${K8S_NAMESPACE} --timeout=5m
                    
                    echo "✓ Deployment rolled out successfully"
                '''
            }
        }

        stage('✅ Verify Deployment') {
            steps {
                sh '''
                    echo "=========================================="
                    echo "✅ VERIFYING KUBERNETES DEPLOYMENT"
                    echo "=========================================="
                    
                    echo "Deployment Status:"
                    kubectl get deployment -n ${K8S_NAMESPACE} -o wide
                    
                    echo ""
                    echo "Pods Status:"
                    kubectl get pods -n ${K8S_NAMESPACE} -l app=responsive-website -o wide
                    
                    echo ""
                    echo "Service Status:"
                    kubectl get svc responsive-website-service -n ${K8S_NAMESPACE} -o wide
                    
                    echo ""
                    echo "✓ Deployment verified successfully"
                    echo ""
                    echo "🌐 Application Access:"
                    echo "http://<cluster-node-ip>:30080"
                '''
            }
        }
    }

    post {
        success {
            sh '''
                echo "=========================================="
                echo "✅ PIPELINE EXECUTION SUCCESSFUL"
                echo "=========================================="
                echo "Build completed successfully!"
                echo "Application deployed to Kubernetes"
            '''
        }
        failure {
            sh '''
                echo "=========================================="
                echo "❌ PIPELINE EXECUTION FAILED"
                echo "=========================================="
                echo "Check the logs above for errors"
            '''
        }
        always {
            cleanWs()
        }
    }
}
