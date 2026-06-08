cat > Jenkinsfile <<'EOF'
pipeline {
    agent none

    environment {
        ARTIFACT_NAME = "simple-app-${BUILD_NUMBER}.tar.gz"
        JFROG_URL = "http://host.docker.internal:8082/artifactory"
        JFROG_REPO = "libs-snapshot-local"
    }

    stages {

        stage('Stage 1 - Build using Docker Container Slave') {
            agent {
                docker {
                    image 'alpine:latest'
                    args '-u root'
                }
            }
            steps {
                sh '''
                    echo "Running build inside Docker container slave"
                    mkdir -p build
                    echo "This is my build artifact from Jenkins build number ${BUILD_NUMBER}" > build/output.txt
                    tar -czf ${ARTIFACT_NAME} build/
                    ls -lh
                '''
            }
        }

        stage('Stage 2 - Use Docker Image as Agent') {
            agent {
                docker {
                    image 'ubuntu:22.04'
                    args '-u root'
                }
            }
            steps {
                sh '''
                    echo "This stage is running inside Ubuntu Docker image agent"
                    apt update -y
                    apt install curl -y
                    echo "Docker image agent stage completed"
                '''
            }
        }

        stage('Stage 3 - Upload Artifact to JFrog') {
            agent any
            steps {
                withCredentials([usernamePassword(credentialsId: 'jfrog-creds', usernameVariable: 'JFROG_USER', passwordVariable: 'JFROG_PASS')]) {
                    sh '''
                        echo "Uploading artifact to JFrog Artifactory"
                        curl -u $JFROG_USER:$JFROG_PASS \
                        -T ${ARTIFACT_NAME} \
                        ${JFROG_URL}/${JFROG_REPO}/${ARTIFACT_NAME}
                    '''
                }
            }
        }

        stage('Stage 4 - Create Kubernetes Pod using Jenkins K8s Plugin') {
            agent {
                kubernetes {
                    cloud 'kubernetes'
                    yaml '''
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: jenkins-k8s-agent
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
                        echo "Kubernetes plugin created this pod dynamically"
                        kubectl get pods
                    '''
                }
            }
        }

        stage('Stage 5 - Deploy Application to Kubernetes') {
            agent any
            steps {
                sh '''
                    echo "Deploying application to Kubernetes"
                    kubectl apply -f deployment.yaml
                    kubectl get pods
                    kubectl get deployment
                '''
            }
        }

        stage('Stage 6 - Manual Confirmation') {
            agent any
            steps {
                input message: 'Application deployed successfully. Do you want to destroy it now?', ok: 'Destroy'
            }
        }

        stage('Stage 7 - Destroy Deployment') {
            agent any
            steps {
                sh '''
                    echo "Destroying Kubernetes deployment"
                    kubectl delete -f deployment.yaml
                    kubectl get pods
                '''
            }
        }
    }

    post {
        always {
            echo "Pipeline completed. Running cleanup/post actions."
            archiveArtifacts artifacts: '*.tar.gz', fingerprint: true
            cleanWs()
        }

        success {
            echo "Pipeline completed successfully."
        }

        failure {
            echo "Pipeline failed. Please check logs."
        }
    }
}
EOF
