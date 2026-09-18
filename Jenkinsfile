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

        stage('IaC Scan') {
            steps {
                sh '''
                    . venv/bin/activate
                    pip install checkov --quiet
                    checkov -d terraform/ --compact --quiet
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t ddrc:${BUILD_NUMBER} .'
            }
        }

        stage('Package Lambda') {
            steps {
                sh './scripts/package_lambda.sh'
            }
        }

        stage('Deploy to Lambda') {
            steps {
                sh '''
                    aws lambda update-function-code --function-name ddrc-api \
                        --zip-file fileb://build/ddrc-lambda.zip --region us-west-2
                    aws lambda update-function-code --function-name ddrc-worker \
                        --zip-file fileb://build/ddrc-lambda.zip --region us-west-2
                '''
            }
        }

        stage('Smoke Test') {
            steps {
                sh '''
                    sleep 5
                    curl -sf -X POST https://cgrlbgz4r4.execute-api.us-west-2.amazonaws.com/validate \
                        -H "Content-Type: application/json" \
                        -d '{"service_name": "aurora-mysql", "engine_version": "3.07.1", "instance_class": "db.r6g.large", "region": "us-west-2", "maintenance_window": "sun:03:00-sun:04:00", "requester": "jenkins-smoke-test"}' \
                        | grep -E '"status": "(READY|QUEUED)"'
                '''
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
