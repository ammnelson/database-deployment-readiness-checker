pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Unit Tests') {
            steps {
                sh '''
                    . venv/bin/activate
                    python -m pytest tests/ -v --cov=src --junitxml=reports/test-results.xml
                '''
            }
            post {
                always {
                    junit 'reports/test-results.xml'
                }
            }
        }

        stage('Security Scan') {
            steps {
                sh '''
                    . venv/bin/activate
                    bandit -r src/ -f json -o reports/bandit-report.json || true
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t ddrc:${BUILD_NUMBER} .'
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh 'sudo k3s kubectl apply -f k8s/'
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
        }
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed. Check logs for details.'
        }
    }
}
