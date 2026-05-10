pipeline {

    agent none

    environment {
        ARTIFACTORY_URL = "http://ARTIFACTORY-IP:8081/artifactory"
        REPO_NAME       = "generic-local"
        IMAGE_NAME      = "demo-app"
        BUILD_VERSION   = "${BUILD_NUMBER}"
    }

    stages {

        // =========================================================
        // STAGE 1 - DOCKER CONTAINER AS JENKINS AGENT (SLAVE)
        // =========================================================

        stage('Build using Docker Slave') {

            agent {
                docker {
                    image 'maven:3.9.6-eclipse-temurin-17'
                    args '-v /var/run/docker.sock:/var/run/docker.sock'
                }
            }

            steps {

                echo "Running build inside Docker container slave"

                sh 'mvn clean package'

                sh '''
                mkdir -p artifacts
                cp target/*.jar artifacts/
                '''
            }

            post {
                success {
                    echo "Build completed successfully"
                }

                failure {
                    echo "Build failed"
                }
            }
        }

        // =========================================================
        // STAGE 2 - USE DOCKER IMAGE AS AGENT
        // =========================================================

        stage('Build Docker Image') {

            agent {
                docker {
                    image 'docker:27.0.3'
                    args '-v /var/run/docker.sock:/var/run/docker.sock'
                }
            }

            steps {

                echo "Building Docker image"

                sh """
                docker build -t ${IMAGE_NAME}:${BUILD_VERSION} .
                docker save ${IMAGE_NAME}:${BUILD_VERSION} > ${IMAGE_NAME}.tar
                """
            }
        }

        // =========================================================
        // UPLOAD TO JFROG
        // =========================================================

        stage('Upload Artifact to JFrog') {

            agent any

            steps {

                withCredentials([
                    usernamePassword(
                        credentialsId: 'jfrog-creds',
                        usernameVariable: 'JF_USER',
                        passwordVariable: 'JF_PASS'
                    )
                ]) {

                    sh """
                    curl -u $JF_USER:$JF_PASS \
                    -T artifacts/*.jar \
                    ${ARTIFACTORY_URL}/${REPO_NAME}/demo-app-${BUILD_NUMBER}.jar
                    """

                    sh """
                    curl -u $JF_USER:$JF_PASS \
                    -T ${IMAGE_NAME}.tar \
                    ${ARTIFACTORY_URL}/${REPO_NAME}/${IMAGE_NAME}-${BUILD_NUMBER}.tar
                    """
                }
            }
        }

// KUBERNETES DEPLOYMENT USING K8S PLUGIN

        stage('Deploy to Kubernetes Pod') {

            agent {
                kubernetes {

                    label 'k8s-agent'

                    yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: jenkins-deployer
spec:
  containers:
  - name: kubectl
    image: bitnami/kubectl:latest
    command:
    - cat
    tty: true
"""
                }
            }

            steps {

                container('kubectl') {

                    echo "Deploying application"

                    sh """
                    kubectl apply -f deployment.yaml
                    kubectl apply -f service.yaml
                    """

                    echo "Waiting for deployment"

                    sh """
                    kubectl rollout status deployment/demo-app --timeout=120s
                    """

                    echo "Deployment successful"

                    sh """
                    kubectl get pods
                    kubectl get svc
                    """
                }
            }

            post {

                success {

                    container('kubectl') {

                        echo "Destroying deployment after verification"

                        sh """
                        kubectl delete -f deployment.yaml
                        kubectl delete -f service.yaml
                        """
                    }
                }

                failure {

                    container('kubectl') {

                        echo "Cleaning failed deployment"

                        sh """
                        kubectl delete -f deployment.yaml || true
                        kubectl delete -f service.yaml || true
                        """
                    }
                }
            }
        }
    }

    // =========================================================
    // GLOBAL POST ACTIONS
    // =========================================================

    post {

        always {

            echo "Pipeline completed"

            archiveArtifacts artifacts: 'artifacts/*.jar'

            cleanWs()
        }

        success {

            echo "Pipeline succeeded"
        }

        failure {

            echo "Pipeline failed"
        }
    }
}
