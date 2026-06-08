pipeline {
    agent none

    environment {
        ARTIFACT_NAME = "amazon-app-${BUILD_NUMBER}.tar.gz"
        JFROG_URL = "http://192.168.116.128:8082/artifactory"
        JFROG_REPO = "libs-snapshot-local"
    }

    stages {
        stage('Checkout') {
            agent any
            steps {
                git branch: 'main', url: 'https://github.com/surajjp7/amazon-app.git'
            }
        }

        stage('Build using Docker Container Slave') {
            agent {
                docker {
                    image 'node:18'
                    args '-u root'
                }
            }
            steps {
                sh '''
                    echo "Building amazon-app inside Docker container agent"
                    npm install
                    npm run build || echo "No build script found, continuing"
                    tar -czf ${ARTIFACT_NAME} .
                    ls -lh
                '''
            }
        }

        stage('Use Docker Image as Agent') {
            agent {
                docker {
                    image 'ubuntu:22.04'
                    args '-u root'
                }
            }
            steps {
                sh '''
                    apt update -y
                    apt install curl -y
                    echo "Running inside Ubuntu Docker image agent"
                '''
            }
        }

        stage('Upload Artifact to JFrog') {
            agent any
            steps {
                withCredentials([usernamePassword(credentialsId: 'jfrog-creds', usernameVariable: 'JFROG_USER', passwordVariable: 'JFROG_PASS')]) {
                    sh '''
                        curl -u $JFROG_USER:$JFROG_PASS \
                        -T ${ARTIFACT_NAME} \
                        ${JFROG_URL}/${JFROG_REPO}/${ARTIFACT_NAME}
                    '''
                }
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
                    sh '''
                        kubectl apply -f k8s/deployment.yaml
                        kubectl apply -f k8s/service.yaml
                        kubectl get pods
                        kubectl get svc
                    '''
                }
            }
        }

        stage('Confirmation Before Destroy') {
            agent any
            steps {
                input message: 'Deployment completed. Do you want to destroy it?', ok: 'Destroy'
            }
        }

        stage('Destroy Deployment') {
            agent any
            steps {
                sh '''
                    kubectl delete -f k8s/deployment.yaml
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: '*.tar.gz', fingerprint: true
            cleanWs()
        }
        success {
            echo "Pipeline completed successfully"
        }
        failure {
            echo "Pipeline failed"
        }
    }
}
