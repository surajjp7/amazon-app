pipeline {
    agent any

    environment {
        IMAGE_NAME = "amazon-app"
        IMAGE_TAG  = "${BUILD_NUMBER}"

        WAR_FILE = "Amazon-Web/target/Amazon.war"
        JFROG_URL = "http://192.168.116.128:8082/artifactory"
        JFROG_REPO = "maven-local"
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/surajjp7/amazon-app.git'
            }
        }

        stage('Build WAR inside Docker Container') {
    steps {
        sh '''
            docker run --rm \
            -v $WORKSPACE:/app \
            -w /app \
            maven:3.9.6-eclipse-temurin-17 \
            mvn clean install -DskipTests

            ls -lh Amazon-Web/target/
        '''
    }
}

        stage('Upload WAR to JFrog') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'Jfrog-Artifactory',
                    usernameVariable: 'JFROG_USER',
                    passwordVariable: 'JFROG_PASS'
                )]) {
                    sh '''
                        curl -u $JFROG_USER:$JFROG_PASS \
                        -T ${WAR_FILE} \
                        ${JFROG_URL}/${JFROG_REPO}/Amazon-${BUILD_NUMBER}.war
                    '''
                }
            }
        }

        stage('Build Docker Image Locally') {
            steps {
                sh '''
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                    docker images | grep ${IMAGE_NAME}
                '''
            }
        }

        stage('Load Image into Minikube') {
            steps {
                sh '''
                    minikube image load ${IMAGE_NAME}:${IMAGE_TAG}
                    minikube image load ${IMAGE_NAME}:latest
                '''
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([file(
                    credentialsId: 'k8s-token',
                    variable: 'KUBECONFIG_FILE'
                )]) {
                    sh '''
                        export KUBECONFIG=$KUBECONFIG_FILE

                        kubectl apply -f k8s/deployment.yaml
                        kubectl apply -f k8s/service.yaml

                        kubectl set image deployment/amazon-app \
                        amazon-container=${IMAGE_NAME}:${IMAGE_TAG}

                        kubectl rollout status deployment/amazon-app
                        kubectl get pods -o wide
                        kubectl get svc
                    '''
                }
            }
        }

        stage('Confirmation Before Destroy') {
            steps {
                input message: 'Deployment completed. Do you want to destroy it?', ok: 'Destroy'
            }
        }

        stage('Destroy Kubernetes Resources') {
            steps {
                withCredentials([file(
                    credentialsId: 'k8s-token',
                    variable: 'KUBECONFIG_FILE'
                )]) {
                    sh '''
                        export KUBECONFIG=$KUBECONFIG_FILE

                        kubectl delete -f k8s/service.yaml --ignore-not-found=true
                        kubectl delete -f k8s/deployment.yaml --ignore-not-found=true
                        kubectl get pods
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'Amazon-Web/target/*.war',
                             fingerprint: true,
                             allowEmptyArchive: true
            cleanWs()
        }

        success {
            echo "Pipeline completed successfully"
        }

        failure {
            echo "Pipeline failed. Check console output."
        }
    }
}
