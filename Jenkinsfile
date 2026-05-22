pipeline {
    agent any

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
        NEXUS_DOCKER_REGISTRY = '192.168.0.8:30082'  // Docker registry port on Nexus
        NEXUS_CREDENTIALS = credentials('nexus-credentials')
        
        // ============ Docker Configuration ============
        DOCKER_IMAGE_NAME = "${APP_NAME}"
        DOCKER_IMAGE_TAG = "${BUILD_NUMBER}"
        DOCKER_REGISTRY_URL = "${NEXUS_DOCKER_REGISTRY}/${APP_NAME}"
        
        // ============ DockerHub Configuration ============
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        DOCKERHUB_REPO = "${DOCKERHUB_CREDENTIALS_USR}/${APP_NAME}"
        
        // ============ Kubernetes Configuration ============
        K8S_MASTER = '192.168.0.10'
        K8S_NAMESPACE = 'production'
        K8S_DEPLOYMENT = 'tomcat-deployment'
        
        // ============ Artifact Configuration ============
        BUILD_ARTIFACT = "build/libs/${APP_NAME}-${APP_VERSION}.jar"
        BUILD_DIR = 'build/libs'
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
                    echo "🔍 PERFORMING PRE-FLIGHT CHECKS"
                    echo "=========================================="
                    
                    echo """
                    📍 Your Environment Details:
                    
                    🖥️  Jenkins: http://192.168.0.6:8080
                    🖥️  Master Node: 192.168.0.10
                    🖥️  Worker Node 1: 192.168.0.6 (Jenkins)
                    🖥️  Worker Node 2: 192.168.0.8 (SonarQube + Nexus)
                    
                    🔗 Service URLs:
                    - SonarQube: http://192.168.0.8:30474
                    - Nexus: http://192.168.0.8:30081
                    - Docker Registry: http://192.168.0.8:30082
                    
                    📦 Repository: ${GIT_REPO}
                    🌿 Branch: ${GIT_BRANCH}
                    📱 App Name: ${APP_NAME}
                    📌 Build Number: ${APP_VERSION}
                    """
                    
                    echo "\n✓ Pre-flight checks ready"
                }
            }
        }

        stage('🔌 Connectivity Verification') {
            steps {
                script {
                    echo "=========================================="
                    echo "🔌 VERIFYING CONNECTIVITY"
                    echo "=========================================="
                    
                    // Test SonarQube
                    echo "Checking SonarQube (192.168.0.8:30474)..."
                    sh '''
                        curl -s -o /dev/null -w "%{http_code}" http://192.168.0.8:30474/api/system/health || echo "⚠️ SonarQube unreachable"
                    '''
                    
                    // Test Nexus
                    echo "Checking Nexus (192.168.0.8:30081)..."
                    sh '''
                        curl -s -o /dev/null -w "%{http_code}" http://192.168.0.8:30081/service/rest/v1/health || echo "⚠️ Nexus unreachable"
                    '''
                    
                    // Test Kubernetes
                    echo "Checking Kubernetes cluster..."
                    sh '''
                        kubectl cluster-info
                        echo "Nodes in cluster:"
                        kubectl get nodes -o wide
                    '''
                    
                    echo "✓ Connectivity verification complete"
                }
            }
        }

        stage('📥 Git Checkout') {
            steps {
                script {
                    echo "=========================================="
                    echo "📥 CLONING REPOSITORY"
                    echo "=========================================="
                    
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: "${GIT_BRANCH}"]],
                        userRemoteConfigs: [[url: "${GIT_REPO}"]]
                    ])
                    
                    echo "✓ Repository cloned successfully"
                    sh 'ls -la'
                }
            }
        }

        stage('🔨 Build with Gradle') {
            steps {
                script {
                    echo "=========================================="
                    echo "🔨 BUILDING APPLICATION"
                    echo "=========================================="
                    
                    sh '''
                        chmod +x gradlew
                        ./gradlew clean build -x test
                        
                        echo "Build artifacts:"
                        ls -lh build/libs/
                    '''
                    
                    echo "✓ Build completed successfully"
                }
            }
        }

        stage('🔍 SonarQube Code Analysis') {
            steps {
                script {
                    echo "=========================================="
                    echo "🔍 RUNNING SONARQUBE ANALYSIS"
                    echo "=========================================="
                    
                    sh '''
                        ./gradlew sonarqube \
                          -Dsonar.projectKey=${SONARQUBE_PROJECT_KEY} \
                          -Dsonar.projectName="${SONARQUBE_PROJECT_NAME}" \
                          -Dsonar.sources=src \
                          -Dsonar.host.url=${SONAR_HOST_URL} \
                          -Dsonar.login=${SONAR_LOGIN} \
                          -Dsonar.qualitygate.wait=true
                    '''
                    
                    echo "✓ SonarQube analysis completed"
                    echo "📊 View report: ${SONAR_HOST_URL}/projects"
                }
            }
        }

        stage('⚖️ Quality Gate Check') {
            steps {
                script {
                    echo "=========================================="
                    echo "⚖️ CHECKING QUALITY GATE"
                    echo "=========================================="
                    
                    sh '''
                        sleep 15
                        
                        QUALITY_RESULT=$(curl -s -u admin:${SONAR_LOGIN} \
                          "${SONAR_HOST_URL}/api/qualitygates/project_status?projectKey=${SONARQUBE_PROJECT_KEY}")
                        
                        echo "Quality Gate Response: $QUALITY_RESULT"
                        
                        STATUS=$(echo $QUALITY_RESULT | grep -o '"status":"[^"]*' | cut -d'"' -f4)
                        echo "Status: $STATUS"
                        
                        if [ "$STATUS" == "OK" ]; then
                          echo "✓ Quality Gate PASSED"
                        elif [ "$STATUS" == "WARN" ]; then
                          echo "⚠️ Quality Gate WARNING - Continuing..."
                        else
                          echo "❌ Quality Gate FAILED"
                          exit 1
                        fi
                    '''
                }
            }
        }

        stage('📤 Push WAR to Nexus') {
            steps {
                script {
                    echo "=========================================="
                    echo "📤 PUSHING ARTIFACT TO NEXUS"
                    echo "=========================================="
                    
                    sh '''
                        # Find the built JAR/WAR file
                        ARTIFACT_FILE=$(find build/libs -type f -name "*.jar" -o -name "*.war" | head -1)
                        
                        if [ -z "$ARTIFACT_FILE" ]; then
                          echo "❌ No artifact found!"
                          exit 1
                        fi
                        
                        echo "Uploading: $ARTIFACT_FILE"
                        
                        curl -v -u ${NEXUS_CREDENTIALS_USR}:${NEXUS_CREDENTIALS_PSW} \
                          --upload-file "$ARTIFACT_FILE" \
                          "${NEXUS_URL}/repository/${NEXUS_REPOSITORY}/${APP_NAME}/${APP_VERSION}/$(basename $ARTIFACT_FILE)"
                        
                        echo "✓ Artifact uploaded to Nexus"
                    '''
                }
            }
        }

        stage('🐳 Build Docker Image') {
            steps {
                script {
                    echo "=========================================="
                    echo "🐳 BUILDING DOCKER IMAGE"
                    echo "=========================================="
                    
                    sh '''
                        # Create Dockerfile
                        cat > Dockerfile << 'EOF'
FROM tomcat:9.0-jdk11-openjdk
RUN rm -rf /usr/local/tomcat/webapps/ROOT
COPY build/libs/*.jar /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1
CMD ["catalina.sh", "run"]
EOF
                        
                        echo "Building Docker image..."
                        docker build -t ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} .
                        docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ${DOCKER_IMAGE_NAME}:latest
                        
                        echo "Docker images created:"
                        docker images | grep ${DOCKER_IMAGE_NAME}
                        
                        echo "✓ Docker image built successfully"
                    '''
                }
            }
        }

        stage('🏪 Push to Nexus Docker Registry') {
            steps {
                script {
                    echo "=========================================="
                    echo "🏪 PUSHING TO NEXUS DOCKER REGISTRY"
                    echo "=========================================="
                    
                    sh '''
                        # Login to Nexus Docker Registry
                        echo "${NEXUS_CREDENTIALS_PSW}" | docker login -u ${NEXUS_CREDENTIALS_USR} \
                          --password-stdin ${NEXUS_DOCKER_REGISTRY}
                        
                        # Tag image for Nexus registry
                        docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                          ${NEXUS_DOCKER_REGISTRY}/${APP_NAME}:${DOCKER_IMAGE_TAG}
                        docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                          ${NEXUS_DOCKER_REGISTRY}/${APP_NAME}:latest
                        
                        # Push to Nexus
                        docker push ${NEXUS_DOCKER_REGISTRY}/${APP_NAME}:${DOCKER_IMAGE_TAG}
                        docker push ${NEXUS_DOCKER_REGISTRY}/${APP_NAME}:latest
                        
                        echo "✓ Image pushed to Nexus Registry"
                    '''
                }
            }
        }

        stage('🌐 Push to DockerHub') {
            steps {
                script {
                    echo "=========================================="
                    echo "🌐 PUSHING TO DOCKERHUB"
                    echo "=========================================="
                    
                    sh '''
                        # Login to DockerHub
                        echo "${DOCKERHUB_CREDENTIALS_PSW}" | docker login -u ${DOCKERHUB_CREDENTIALS_USR} \
                          --password-stdin
                        
                        # Tag image for DockerHub
                        docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                          ${DOCKERHUB_REPO}:${DOCKER_IMAGE_TAG}
                        docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                          ${DOCKERHUB_REPO}:latest
                        
                        # Push to DockerHub
                        docker push ${DOCKERHUB_REPO}:${DOCKER_IMAGE_TAG}
                        docker push ${DOCKERHUB_REPO}:latest
                        
                        echo "✓ Image pushed to DockerHub"
                        echo "🔗 Available at: docker.io/${DOCKERHUB_REPO}"
                    '''
                }
            }
        }

        stage('☸️ Deploy to Kubernetes') {
            steps {
                script {
                    echo "=========================================="
                    echo "☸️ DEPLOYING TO KUBERNETES CLUSTER"
                    echo "=========================================="
                    
                    sh '''
                        # Create namespace
                        kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                        
                        # Create docker registry secret for private Nexus registry
                        kubectl delete secret nexus-docker-secret -n ${K8S_NAMESPACE} 2>/dev/null || true
                        kubectl create secret docker-registry nexus-docker-secret \
                          --docker-server=${NEXUS_DOCKER_REGISTRY} \
                          --docker-username=${NEXUS_CREDENTIALS_USR} \
                          --docker-password=${NEXUS_CREDENTIALS_PSW} \
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
        ports:
        - containerPort: 8080
          name: http
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
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 5
          timeoutSeconds: 3
        env:
        - name: CATALINA_OPTS
          value: "-Xmx512M -Xms256M"
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
    name: http
  selector:
    app: responsive-website
DEPLOY
                        
                        # Apply deployment
                        kubectl apply -f deployment.yaml
                        
                        echo "✓ Deployment configuration applied"
                    '''
                }
            }
        }

        stage('⏳ Wait for Rollout') {
            steps {
                script {
                    echo "=========================================="
                    echo "⏳ WAITING FOR DEPLOYMENT ROLLOUT"
                    echo "=========================================="
                    
                    sh '''
                        echo "Waiting for deployment to be ready (max 5 minutes)..."
                        kubectl rollout status deployment/tomcat-deployment \
                          -n ${K8S_NAMESPACE} --timeout=5m
                        
                        echo "✓ Deployment rolled out successfully"
                    '''
                }
            }
        }

        stage('✅ Verify Deployment') {
            steps {
                script {
                    echo "=========================================="
                    echo "✅ VERIFYING KUBERNETES DEPLOYMENT"
                    echo "=========================================="
                    
                    sh '''
                        echo "📊 Deployment Status:"
                        kubectl get deployment -n ${K8S_NAMESPACE} -o wide
                        
                        echo "\n📦 Pods Status:"
                        kubectl get pods -n ${K8S_NAMESPACE} -l app=responsive-website -o wide
                        
                        echo "\n🔗 Service Status:"
                        kubectl get svc responsive-website-service -n ${K8S_NAMESPACE} -o wide
                        
                        echo "\n🌐 Application Access:"
                        NODES=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
                        for node in $NODES; do
                          echo "http://$node:30080"
                        done
                        
                        echo "\n✓ Deployment verified successfully"
                    '''
                }
            }
        }

        stage('📊 Generate Report') {
            steps {
                script {
                    echo "=========================================="
                    echo "📊 PIPELINE SUMMARY REPORT"
                    echo "=========================================="
                    
                    sh '''
                        echo """
                        
                        ╔════════════════════════════════════════════════════╗
                        ║           BUILD SUCCESS SUMMARY                    ║
                        ╚════════════════════════════════════════════════════╝
                        
                        📱 Application: ${APP_NAME}
                        📌 Build Number: ${APP_VERSION}
                        🔗 Repository: ${GIT_REPO}
                        🌿 Branch: ${GIT_BRANCH}
                        
                        ✅ Pipeline Stages Completed:
                           ✓ Pre-Flight Checks
                           ✓ Connectivity Verification
                           ✓ Git Checkout
                           ✓ Gradle Build
                           ✓ SonarQube Analysis
                           ✓ Quality Gate Check
                           ✓ Nexus Artifact Upload
                           ✓ Docker Image Build
                           ✓ Nexus Docker Registry Push
                           ✓ DockerHub Push
                           ✓ Kubernetes Deployment
                           ✓ Rollout Verification
                        
                        🐳 Docker Image:
                           - Nexus: ${NEXUS_DOCKER_REGISTRY}/${APP_NAME}:${DOCKER_IMAGE_TAG}
                           - DockerHub: ${DOCKERHUB_REPO}:${DOCKER_IMAGE_TAG}
                        
                        ☸️  Kubernetes Deployment:
                           - Namespace: ${K8S_NAMESPACE}
                           - Deployment: ${K8S_DEPLOYMENT}
                           - Replicas: 3
                           - Service: responsive-website-service (NodePort: 30080)
                        
                        🔗 Access URLs:
                           - Jenkins: http://192.168.0.6:8080
                           - SonarQube: http://192.168.0.8:30474
                           - Nexus: http://192.168.0.8:30081
                           - Application: http://<cluster-node-ip>:30080
                        
                        📈 View Logs:
                           kubectl logs -f deployment/tomcat-deployment -n ${K8S_NAMESPACE}
                           kubectl describe pod -n ${K8S_NAMESPACE} -l app=responsive-website
                        
                        ⏱️  Build Duration: ${BUILD_DURATION}
                        
                        ╚════════════════════════════════════════════════════╝
                        
                        """
                    '''
                }
            }
        }
    }

    post {
        success {
            script {
                echo "=========================================="
                echo "✅ PIPELINE EXECUTION SUCCESSFUL"
                echo "=========================================="
                
                emailext(
                    subject: "✅ Build SUCCESS: ${APP_NAME} #${BUILD_NUMBER}",
                    body: """
                        <h2>✅ Build Successful!</h2>
                        
                        <p><b>Application:</b> ${APP_NAME}</p>
                        <p><b>Build Number:</b> ${BUILD_NUMBER}</p>
                        <p><b>Status:</b> SUCCESS ✓</p>
                        
                        <h3>🎯 Pipeline Steps Completed:</h3>
                        <ul>
                          <li>✓ Code Checkout</li>
                          <li>✓ Gradle Build</li>
                          <li>✓ SonarQube Analysis</li>
                          <li>✓ Quality Gate Check</li>
                          <li>✓ Artifact to Nexus</li>
                          <li>✓ Docker Build</li>
                          <li>✓ Push to Nexus Registry</li>
                          <li>✓ Push to DockerHub</li>
                          <li>✓ Kubernetes Deployment</li>
                        </ul>
                        
                        <h3>🔗 Access URLs:</h3>
                        <ul>
                          <li>Jenkins: <a href="http://192.168.0.6:8080">http://192.168.0.6:8080</a></li>
                          <li>SonarQube: <a href="http://192.168.0.8:30474">http://192.168.0.8:30474</a></li>
                          <li>Nexus: <a href="http://192.168.0.8:30081">http://192.168.0.8:30081</a></li>
                          <li>Application: http://&lt;cluster-node-ip&gt;:30080</li>
                        </ul>
                        
                        <h3>🐳 Docker Image:</h3>
                        <p>
                          - Nexus: ${NEXUS_DOCKER_REGISTRY}/${APP_NAME}:${DOCKER_IMAGE_TAG}<br>
                          - DockerHub: ${DOCKERHUB_REPO}:${DOCKER_IMAGE_TAG}
                        </p>
                        
                        <p><a href="${BUILD_URL}">View Build Details</a></p>
                    """,
                    to: '${DEFAULT_RECIPIENTS}',
                    mimeType: 'text/html'
                )
            }
        }
        
        failure {
            script {
                echo "=========================================="
                echo "❌ PIPELINE EXECUTION FAILED"
                echo "=========================================="
                
                emailext(
                    subject: "❌ Build FAILED: ${APP_NAME} #${BUILD_NUMBER}",
                    body: """
                        <h2>❌ Build Failed!</h2>
                        
                        <p><b>Application:</b> ${APP_NAME}</p>
                        <p><b>Build Number:</b> ${BUILD_NUMBER}</p>
                        <p><b>Failed Stage:</b> ${env.STAGE_NAME}</p>
                        
                        <h3>⚠️ Troubleshooting:</h3>
                        <ul>
                          <li>Check SonarQube Quality Gate: http://192.168.0.8:30474</li>
                          <li>Check Nexus connectivity: http://192.168.0.8:30081</li>
                          <li>Check Kubernetes cluster status: kubectl get nodes</li>
                          <li>View Jenkins logs for detailed errors</li>
                        </ul>
                        
                        <p><a href="${BUILD_URL}console">View Console Output</a></p>
                    """,
                    to: '${DEFAULT_RECIPIENTS}',
                    mimeType: 'text/html'
                )
            }
        }
        
        always {
            script {
                echo "=========================================="
                echo "🧹 CLEANUP"
                echo "=========================================="
                
                cleanWs()
            }
        }
    }
}
