pipeline {
    agent {
        dockerfile {
            filename 'Dockerfile'
            args '-v /root/.m2:/root/.m2 -v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    environment {
        DOCKERHUB_AUTH = credentials('kacissokho')
        MYSQL_AUTH = credentials('MYSQL_AUTH')
        IMAGE_NAME = 'paymybuddy'
        IMAGE_TAG = 'latest'
        HOSTNAME_DEPLOY_STAGING = "54.92.175.115"
        HOSTNAME_DEPLOY_PROD = "54.226.144.55"
    }

    stages {

        stage('Test') {
            steps {
                sh 'mvn clean test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('Package') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Build and push IMAGE to docker registry') {
            steps {
                sh """
                    docker build --secret id=db_user,env=SPRING_DATASOURCE_USER --secret id=db_password,env=SPRING_DATASOURCE_PASSWORD -t ${DOCKERHUB_AUTH_USR}/${IMAGE_NAME}:${IMAGE_TAG} .
                    echo ${DOCKERHUB_AUTH_PSW} | docker login -u ${DOCKERHUB_AUTH_USR} --password-stdin
                    docker push ${DOCKERHUB_AUTH_USR}/${IMAGE_NAME}:${IMAGE_TAG}
                """
            }
        }

        stage('Deploy in staging') {
            when {
                expression { GIT_BRANCH == 'main' }
            }
            steps {
                sshagent(credentials: ['SSH_AUTH_SERVER']) { 
                    sh '''
                        [ -d ~/.ssh ] || mkdir ~/.ssh && chmod 0700 ~/.ssh
                        ssh-keyscan -t rsa,dsa ${HOSTNAME_DEPLOY_STAGING} >> ~/.ssh/known_hosts
                        scp -r deploy ubuntu@${HOSTNAME_DEPLOY_STAGING}:/home/ubuntu/
                        command1="cd deploy && echo ${DOCKERHUB_AUTH_PSW} | docker login -u ${DOCKERHUB_AUTH_USR} --password-stdin"
                        command2="echo 'IMAGE_VERSION=${DOCKERHUB_AUTH_USR}/${IMAGE_NAME}:${IMAGE_TAG}' > .env && echo ${MYSQL_AUTH_PSW} > secrets/db_password.txt && echo ${MYSQL_AUTH_USR} > secrets/db_user.txt"
                        command3="docker compose down && docker pull ${DOCKERHUB_AUTH_USR}/${IMAGE_NAME}:${IMAGE_TAG}"
                        command4="docker compose up -d"
                        ssh -t ubuntu@${HOSTNAME_DEPLOY_STAGING} \
                            -o SendEnv=IMAGE_NAME \
                            -o SendEnv=IMAGE_TAG \
                            -o SendEnv=DOCKERHUB_AUTH_USR \
                            -o SendEnv=DOCKERHUB_AUTH_PSW \
                            -o SendEnv=MYSQL_AUTH_USR \
                            -o SendEnv=MYSQL_AUTH_PSW \
                            -C "$command1 && $command2 && $command3 && $command4"
                    '''
                }
            }
        }

        stage('Test Staging') {
            when {
                expression { GIT_BRANCH == 'main' }
            }
            steps {
                sh '''
                    sleep 30
                    sudo apt-get update -y && sudo apt-get install -y curl
                    curl ${HOSTNAME_DEPLOY_STAGING}:8080
                '''
            }
        }

        stage('Deploy in prod') {
            when {
                expression { GIT_BRANCH == 'main' }
            }
            steps {
                sshagent(credentials: ['SSH_AUTH_SERVER']) { 
                    sh '''
                        [ -d ~/.ssh ] || mkdir ~/.ssh && chmod 0700 ~/.ssh
                        ssh-keyscan -t rsa,dsa ${HOSTNAME_DEPLOY_PROD} >> ~/.ssh/known_hosts
                        scp -r deploy ubuntu@${HOSTNAME_DEPLOY_PROD}:/home/ubuntu/
                        command1="cd deploy && echo ${DOCKERHUB_AUTH_PSW} | docker login -u ${DOCKERHUB_AUTH_USR} --password-stdin"
                        command2="echo 'IMAGE_VERSION=${DOCKERHUB_AUTH_USR}/${IMAGE_NAME}:${IMAGE_TAG}' > .env && echo ${MYSQL_AUTH_PSW} > secrets/db_password.txt && echo ${MYSQL_AUTH_USR} > secrets/db_user.txt"
                        command3="docker compose down && docker pull ${DOCKERHUB_AUTH_USR}/${IMAGE_NAME}:${IMAGE_TAG}"
                        command4="docker compose up -d"
                        ssh -t ubuntu@${HOSTNAME_DEPLOY_PROD} \
                            -o SendEnv=IMAGE_NAME \
                            -o SendEnv=IMAGE_TAG \
                            -o SendEnv=DOCKERHUB_AUTH_USR \
                            -o SendEnv=DOCKERHUB_AUTH_PSW \
                            -o SendEnv=MYSQL_AUTH_USR \
                            -o SendEnv=MYSQL_AUTH_PSW \
                            -C "$command1 && $command2 && $command3 && $command4"
                    '''
                }
            }
        }

        stage('Test Prod') {
            when {
                expression { GIT_BRANCH == 'main' }
            }
            steps {
                sh '''
                    sleep 30
                    sudo apt-get update -y && sudo apt-get install -y curl
                    curl ${HOSTNAME_DEPLOY_PROD}:8080
                '''
            }
        }
    }
}
