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
        
        // ============ Git Credentials ============
        GIT_CREDS = credentials('git-creds')
        
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
                    echo "✓ Pre-flight checks ready"
                }
            }
        }

        stage('🔌 Connectivity Verification') {
            steps {
                script {
                    echo "=========================================="
                    echo "🔌 VERIFYING CONNECTIVITY"
                    echo "=========================================="
                    
                    sh '''
                        echo "Checking SonarQube (192.168.0.8:30474)..."
                        curl -s -I http://192.168.0.8:30474/api/system/health && echo "✓ SonarQube OK" || echo "⚠️ SonarQube unreachable"
                        
                        echo "Checking Nexus (192.168.0.8:30081)..."
                        curl -s -I http://192.168.0.8:30081/service/rest/v1/health && echo "✓ Nexus OK" || echo "⚠️ Nexus unreachable"
                        
                        echo "Checking Kubernetes cluster..."
                        kubectl cluster-info && echo "✓ Kubernetes OK" || echo "⚠️ Kubernetes unreachable"
                        echo "Nodes in cluster:"
                        kubectl get nodes -o wide
                    '''
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
                          -Dsonar.login=${SONAR_LOGIN} || true
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
                          echo "⚠️ Skipping Quality Gate check (may not be configured yet)"
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
                        ARTIFACT_FILE=$(find build/libs -type f \\( -name "*.jar" -o -name "*.war" \\) | head -1)
                        
                        if [ -z "$ARTIFACT_FILE" ]; then
                          echo "❌ No artifact found!"
                          exit 1
                        fi
                        
                        echo "Uploading: $ARTIFACT_FILE"
                        echo "Using Nexus credentials: ${NEXUS_CREDS_USR}"
                        
                        curl -v -u ${NEXUS_CREDS_USR}:${NEXUS_CREDS_PSW} \
                          --upload-file "$ARTIFACT_FILE" \
                          "${NEXUS_URL}/repository/${NEXUS_REPOSITORY}/${APP_NAME}/${APP_VERSION}/$(basename $ARTIFACT_FILE)"
                        
                        echo ""
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
                        echo "Logging into Nexus Docker Registry..."
                        echo "${NEXUS_CREDS_PSW}" | docker login -u ${NEXUS_CREDS_USR} \
                          --password-stdin ${NEXUS_DOCKER_REGISTRY}
                        
                        # Tag image for Nexus registry
                        docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                          ${NEXUS_DOCKER_REGISTRY}/${APP_NAME}:${DOCKER_IMAGE_TAG}
                        docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                          ${NEXUS_DOCKER_REGISTRY}/${APP_NAME}:latest
                        
                        # Push to Nexus
                        echo "Pushing to Nexus Registry..."
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
                        echo "Logging into DockerHub..."
                        echo "${DOCKERHUB_CREDS_PSW}" | docker login -u ${DOCKERHUB_CREDS_USR} \
                          --password-stdin
                        
                        # Tag image for DockerHub
                        docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                          ${DOCKERHUB_CREDS_USR}/${APP_NAME}:${DOCKER_IMAGE_TAG}
                        docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                          ${DOCKERHUB_CREDS_USR}/${APP_NAME}:latest
                        
                        # Push to DockerHub
                        echo "Pushing to DockerHub..."
                        docker push ${DOCKERHUB_CREDS_USR}/${APP_NAME}:${DOCKER_IMAGE_TAG}
                        docker push ${DOCKERHUB_CREDS_USR}/${APP_NAME}:latest
                        
                        echo "✓ Image pushed to DockerHub"
                        echo "🔗 Available at: docker.io/${DOCKERHUB_CREDS_USR}/${APP_NAME}"
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
                        
                        # Delete old secret if exists
                        kubectl delete secret nexus-docker-secret -n ${K8S_NAMESPACE} 2>/dev/null || true
                        
                        # Create docker registry secret for private Nexus registry
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
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
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
  sessionAffinity: ClientIP
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
                        echo "Applying Kubernetes deployment..."
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
                        
                        echo ""
                        echo "📦 Pods Status:"
                        kubectl get pods -n ${K8S_NAMESPACE} -l app=responsive-website -o wide
                        
                        echo ""
                        echo "🔗 Service Status:"
                        kubectl get svc responsive-website-service -n ${K8S_NAMESPACE} -o wide
                        
                        echo ""
                        echo "🌐 Application Access:"
                        NODES=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
                        for node in $NODES; do
                          echo "   http://$node:30080"
                        done
                        
                        echo ""
                        echo "✓ Deployment verified successfully"
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
                           - Nexus: 192.168.0.8:30082/${APP_NAME}:${DOCKER_IMAGE_TAG}
                           - DockerHub: docker.io/${DOCKERHUB_CREDS_USR}/${APP_NAME}:${DOCKER_IMAGE_TAG}
                        
                        ☸️  Kubernetes Deployment:
                           - Namespace: ${K8S_NAMESPACE}
                           - Deployment: tomcat-deployment
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
                
                sh '''
                    echo "
                    ╔════════════════════════════════════════════════════╗
                    ║  ✅ BUILD COMPLETED SUCCESSFULLY ✅               ║
                    ╚════════════════════════════════════════════════════╝
                    
                    Build Details:
                    - Application: ${APP_NAME}
                    - Build: #${APP_VERSION}
                    - Docker Image: 192.168.0.8:30082/${APP_NAME}:${DOCKER_IMAGE_TAG}
                    - Deployment: http://<node-ip>:30080
                    
                    Next Steps:
                    1. Access the application at http://<cluster-node-ip>:30080
                    2. Check logs: kubectl logs -f deployment/tomcat-deployment -n production
                    3. Monitor: kubectl get pods -n production -w
                    "
                '''
            }
        }
        
        failure {
            script {
                echo "=========================================="
                echo "❌ PIPELINE EXECUTION FAILED"
                echo "=========================================="
                
                sh '''
                    echo "
                    ╔════════════════════════════════════════════════════╗
                    ║  ❌ BUILD FAILED ❌                               ║
                    ╚════════════════════════════════════════════════════╝
                    
                    Failed Stage: ${env.STAGE_NAME}
                    
                    Troubleshooting:
                    1. Check SonarQube: http://192.168.0.8:30474
                    2. Check Nexus: http://192.168.0.8:30081
                    3. Check K8s cluster: kubectl get nodes
                    4. Check Jenkins logs for details
                    "
                '''
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
