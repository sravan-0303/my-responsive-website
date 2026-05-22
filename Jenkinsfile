pipeline {
    agent any

    environment {
        // ============ GIT ============
        GIT_REPO = 'https://github.com/Krishnamohan-Yerrabilli/Java_Gradle_Responsive_Website.git'
        GIT_BRANCH = 'main'

        // ============ APP ============
        APP_NAME = 'responsive-website'
        APP_VERSION = "${BUILD_NUMBER}"

        // ============ SONAR ============
        SONAR_HOST_URL = 'http://192.168.0.8:30474'
        SONAR_LOGIN = credentials('sonarqube-token')
        SONARQUBE_PROJECT_KEY = 'responsive-website'
        SONARQUBE_PROJECT_NAME = 'Responsive Website'

        // ============ NEXUS ============
        NEXUS_URL = 'http://192.168.0.8:30081'
        NEXUS_REPOSITORY = 'java-releases'
        NEXUS_DOCKER_REGISTRY = '192.168.0.8:30082'
        NEXUS_CREDS = credentials('nexus-creds')

        // ============ DOCKER ============
        DOCKER_IMAGE_NAME = "${APP_NAME}"
        DOCKER_IMAGE_TAG = "${BUILD_NUMBER}"

        // ============ DOCKERHUB ============
        DOCKERHUB_CREDS = credentials('dockerhub-creds')
        DOCKERHUB_REPO = "${DOCKERHUB_CREDS_USR}/${APP_NAME}"

        // ============ K8S ============
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
                '''
            }
        }

        stage('Git Checkout') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "${GIT_BRANCH}"]],
                    userRemoteConfigs: [[url: "${GIT_REPO}"]]
                ])
            }
        }

        stage('Build') {
            steps {
                sh '''
                    chmod +x gradlew
                    ./gradlew clean build -x test
                    ls -lh build/libs/
                '''
            }
        }

        stage('SonarQube') {
            steps {
                sh '''
                    ./gradlew sonarqube \
                    -Dsonar.projectKey=${SONARQUBE_PROJECT_KEY} \
                    -Dsonar.projectName="${SONARQUBE_PROJECT_NAME}" \
                    -Dsonar.sources=src \
                    -Dsonar.host.url=${SONAR_HOST_URL} \
                    -Dsonar.login=${SONAR_LOGIN} || true
                '''
            }
        }

        stage('Push to Nexus') {
            steps {
                sh '''
                    ARTIFACT=$(find build/libs -type f -name "*.jar" -o -name "*.war" | head -1)

                    echo "Artifact: $ARTIFACT"

                    curl -v -u ${NEXUS_CREDS_USR}:${NEXUS_CREDS_PSW} \
                    --upload-file "$ARTIFACT" \
                    "${NEXUS_URL}/repository/${NEXUS_REPOSITORY}/${APP_NAME}/${APP_VERSION}/$(basename $ARTIFACT)"
                '''
            }
        }

        stage('Docker Build') {
            steps {
                sh '''
cat > Dockerfile <<EOF
FROM tomcat:9.0-jdk11
RUN rm -rf /usr/local/tomcat/webapps/ROOT
COPY build/libs/*.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
CMD ["catalina.sh","run"]
EOF

docker build -t ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} .
docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ${DOCKER_IMAGE_NAME}:latest
                '''
            }
        }

        stage('Push DockerHub') {
            steps {
                sh '''
echo "${DOCKERHUB_CREDS_PSW}" | docker login -u ${DOCKERHUB_CREDS_USR} --password-stdin

docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ${DOCKERHUB_REPO}:${DOCKER_IMAGE_TAG}
docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ${DOCKERHUB_REPO}:latest

docker push ${DOCKERHUB_REPO}:${DOCKER_IMAGE_TAG}
docker push ${DOCKERHUB_REPO}:latest
                '''
            }
        }

        stage('Kubernetes Deploy') {
            steps {
                sh '''
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
      containers:
      - name: tomcat
        image: ${DOCKER_IMAGE_NAME}:latest
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
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080
  selector:
    app: responsive-website
EOF

kubectl apply -f deployment.yaml
                '''
            }
        }

        stage('Verify') {
            steps {
                sh '''
kubectl get pods -n ${K8S_NAMESPACE}
kubectl get svc -n ${K8S_NAMESPACE}
                '''
            }
        }
    }

    post {
    always {
        script {
            if (currentBuild.rawBuild.getWorkspace() != null) {
                deleteDir()
            }
        }
    }
}
}
