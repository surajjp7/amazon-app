pipeline {
    agent any

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', credentialsId: 'GitHub', url: 'https://github.com/surajjp7/amazon-app.git'
            }
        }
    }
}
