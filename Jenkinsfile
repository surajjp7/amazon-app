pipeline {
    agent none

    environment {
        APP_NAME = "amazon-app"
        IMAGE_NAME = "amazon-app"
        IMAGE_TAG = "${BUILD_NUMBER}"

        WAR_FILE = "Amazon-Web/target/Amazon.war"
        ARTIFACT_NAME = "Amazon-${BUILD_NUMBER}.war"

        JFROG_URL = "http://192.168.116.128:8082/artifactory"
        JFROG_REPO = "maven-local"
    }

    stages {

        stage('Checkout') {
            agent any
            steps {
                git branch: 'main',
                    url: 'https://github.com/surajjp7/amazon-app.git'
            }
        }

        stage('Build WAR using Docker Container Slave') {
            agent {
                docker {
                    image 'maven:3.9.6-eclipse-temurin-17'
                    args '-u root'
                }
            }
            steps {
                sh '''
                    echo "Building Maven WAR inside Docker container slave"
                    mvn clean package
                    ls -lh Amazon-Web/target/
                '''

                stash name: 'source-code', includes: '**/*'
                stash name: 'war-file', includes: 'Amazon-Web/target/Amazon.war'
            }
        }

        stage('Upload WAR Artifact to JFrog') {
            agent any
            steps {
                unstash 'war-file'

                withCredentials([usernamePassword(
                    credentialsId: 'jfrog-creds',
                    usernameVariable: 'JFROG_USER',
                    passwordVariable: 'JFROG_PASS'
                )]) {
                    sh '''
                        echo "Uploading WAR artifact to JFrog"
                        curl -u $JFROG_USER:$JFROG_PASS \
                        -T ${WAR_FILE} \
                        ${JFROG_URL}/${JFROG_REPO}/${ARTIFACT_NAME}
                    '''
                }
            }
        }

        stage('Build Docker Image Locally') {
            agent any
            steps {
                unstash 'source-code'

                sh '''
                    echo "Building Docker image locally on Ubuntu VM"
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                    docker images | grep ${IMAGE_NAME}
                '''
            }
        }

        stage('Load Docker Image into Minikube') {
            agent any
            steps {
                sh '''
                    echo "Loading Docker image into Minikube"
                    minikube image load ${IMAGE_NAME}:${IMAGE_TAG}
                    minikube image load ${IMAGE_NAME}:latest
                '''
            }
        }

        stage('Deploy using Kubernetes Plugin Pod') {
            agent {
                kubernetes {
                    cloud 'kubernetes'
                    yaml '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins
  containers:
  - name: kubectl
    image: bitnami/kubectl:latest
    command:
    - cat
    tty: true
'''
                }
            }
            steps {
                container('kubectl') {
                    unstash 'source-code'

                    sh '''
                        echo "Deploying application to Kubernetes"
                        kubectl apply -f deployment.yaml
                        kubectl apply -f service.yaml
                        kubectl set image deployment/amazon-app amazon-container=${IMAGE_NAME}:${IMAGE_TAG}
                        kubectl rollout status deployment/amazon-app
                        kubectl get pods -o wide
                        kubectl get svc
                    '''
                }
            }
        }

        stage('Confirmation Before Destroy') {
            agent any
            steps {
                input message: 'Application deployed successfully. Do you want to destroy it?', ok: 'Destroy'
            }
        }

        stage('Destroy Kubernetes Resources') {
            agent {
                kubernetes {
                    cloud 'kubernetes'
                    yaml '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins
  containers:
  - name: kubectl
    image: bitnami/kubectl:latest
    command:
    - cat
    tty: true
'''
                }
            }
            steps {
                container('kubectl') {
                    unstash 'source-code'

                    sh '''
                        echo "Destroying Kubernetes resources"
                        kubectl delete -f service.yaml --ignore-not-found=true
                        kubectl delete -f deployment.yaml --ignore-not-found=true
                        kubectl get pods
                    '''
                }
            }
        }
    }

    post {
        always {
            node {
                echo "Running post actions"
                archiveArtifacts artifacts: 'Amazon-Web/target/*.war', fingerprint: true, allowEmptyArchive: true
                cleanWs()
            }
        }

        success {
            echo "Pipeline completed successfully"
        }

        failure {
            echo "Pipeline failed. Check Jenkins console logs."
        }
    }
}
