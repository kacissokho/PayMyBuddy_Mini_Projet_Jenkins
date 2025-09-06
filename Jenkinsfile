pipeline {
    agent any

    environment {
        REGISTRY = "kacissokho"
        IMAGE_NAME = "paymybuddy"
        IMAGE_TAG = "v1.4"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Linter') {
            steps {
                sh '''
                    set -eu
                    if [ -f Dockerfile ]; then
                        echo "Lance hadolint sur le Dockerfile…"
                        docker run --rm -i hadolint/hadolint hadolint - < Dockerfile
                    else
                        echo "Pas de Dockerfile trouvé."
                    fi
                '''
            }
        }

        stage('Build image') {
            steps {
                sh '''
                    docker build -t $REGISTRY/$IMAGE_NAME:$IMAGE_TAG .
                '''
            }
        }

        stage('Scan sécurité image') {
            options {
                timeout(time: 10, unit: 'MINUTES')
            }
            steps {
                script {
                    sh '''
                        set -eu
                        echo "Scan de sécurité avec Trivy (avec cache local)…"
                        docker run --rm \
                          -v /var/run/docker.sock:/var/run/docker.sock \
                          -v $HOME/.cache:/root/.cache \
                          aquasec/trivy:latest image \
                          --no-progress \
                          --scanners vuln \
                          --severity HIGH,CRITICAL \
                          --exit-code 1 \
                          $REGISTRY/$IMAGE_NAME:$IMAGE_TAG
                    '''
                }
            }
        }

        stage('Heroku:déployer STAGING') {
            when {
                expression { currentBuild.currentResult == "SUCCESS" }
            }
            steps {
                sh '''
                    echo "Déploiement sur Heroku STAGING…"
                    # heroku container:push web --app $HEROKU_APP_STAGING
                    # heroku container:release web --app $HEROKU_APP_STAGING
                '''
            }
        }

        stage('Test STAGING') {
            when {
                expression { currentBuild.currentResult == "SUCCESS" }
            }
            steps {
                sh 'echo "Tests sur STAGING (à implémenter)"'
            }
        }

        stage('Heroku: déployer PROD') {
            when {
                expression { currentBuild.currentResult == "SUCCESS" }
            }
            steps {
                sh '''
                    echo "Déploiement sur Heroku PROD…"
                    # heroku container:push web --app $HEROKU_APP_PROD
                    # heroku container:release web --app $HEROKU_APP_PROD
                '''
            }
        }

        stage('Test Production') {
            when {
                expression { currentBuild.currentResult == "SUCCESS" }
            }
            steps {
                sh 'echo "Tests sur PROD (à implémenter)"'
            }
        }
    }

    post {
        always {
            slackSend(
                teamDomain: 'pozosworkspace',
                channel: 'C09CTBMC74N',
                tokenCredentialId: 'slack_token',
                message: "Build terminé avec le statut: ${currentBuild.currentResult}"
            )
        }
    }
}
