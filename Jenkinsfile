pipeline {
    agent {
        dockerfile {
            filename 'agent/Dockerfile'
            args '-v /root/.m2:/root/.m2 -v /var/run/docker.sock:/var/run/docker.sock'
        }
    }


    environment {
        DOCKERHUB_AUTH = credentials('DockerHubCredentials')
        MYSQL_AUTH= credentials('MYSQL_AUTH')
        HOSTNAME_DEPLOY_PROD = "3.85.13.86"
        HOSTNAME_DEPLOY_STAGING = "34.207.86.25"
        IMAGE_NAME= 'paymybuddy'
        IMAGE_TAG= 'latest'

        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id') // ID de votre clé d'accès AWS
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key') // Secret de votre clé d'accès AWS
        REGION = 'us-east-1' // Remplacez par votre région AWS préférée
        INSTANCE_TYPE = 't2.medium'
        AMI_ID = 'ami-067ec4a660257c294'
        KEY_NAME = 'deploy-review'
        SECURITY_GROUP = 'sg-0edde05d6495254c7' // Remplacez par votre groupe de sécurité
        STORAGE = 100
    }

    stages {

        stage('Create EC2 Instance') {
            steps {
                script {
                    // Installer AWS CLI
                    sh '''
                        apk add --no-cache python3 py3-pip
                        pip3 install awscli
                    '''

                    // Construire le tag à partir du nom de la branche
                    def branchName = env.BRANCH_NAME ?: 'unknown' // Nom de la branche
                    def tag = "review-${branchName}"

                    // Commande pour créer l'instance EC2
                    def createInstanceCommand = """
                        aws ec2 run-instances \
                        --image-id ${AMI_ID} \
                        --count 1 \
                        --instance-type ${INSTANCE_TYPE} \
                        --key-name ${KEY_NAME} \
                        --security-group-ids ${SECURITY_GROUP} \
                        --block-device-mappings DeviceName=/dev/sda1,Ebs={VolumeSize=${STORAGE}}} \
                        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=${tag}}]'
                    """
                    
                    // Exécuter la commande
                    sh createInstanceCommand
                }
            }
        }

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

        stage('SonarCloud analysis') {
            steps {
                withSonarQubeEnv('SonarCloudServer') {
                    sh 'mvn sonar:sonar -s .m2/settings.xml'
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 60, unit: 'SECONDS') {
                    waitForQualityGate abortPipeline: false
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
                    docker build -t ${DOCKERHUB_AUTH_USR}/${IMAGE_NAME}:${IMAGE_TAG} .
                    echo ${DOCKERHUB_AUTH_PSW} | docker login -u ${DOCKERHUB_AUTH_USR} --password-stdin
                    docker push ${DOCKERHUB_AUTH_USR}/${IMAGE_NAME}:${IMAGE_TAG}
                """
            }
        }

        stage ('Deploy in staging') {
            when {
                expression { GIT_BRANCH == 'origin/training' }
            }
            steps {
                sshagent(credentials: ['SSH_AUTH_SERVER']) { 
                    sh '''
                        [ -d ~/.ssh ] || mkdir ~/.ssh && chmod 0700 ~/.ssh
                        ssh-keyscan -t rsa,dsa ${HOSTNAME_DEPLOY_STAGING} >> ~/.ssh/known_hosts
                        scp -r deploy ubuntu@${HOSTNAME_DEPLOY_STAGING}:/home/ubuntu/
                        command1="cd deploy && echo ${DOCKERHUB_AUTH_PSW} | docker login -u ${DOCKERHUB_AUTH_USR} --password-stdin"
                        command2="echo 'IMAGE_VERSION=${DOCKERHUB_AUTH_USR}/${IMAGE_NAME}:${IMAGE_TAG}' > .env && echo ${MYSQL_AUTH_PSW} > secrets/db_password.txt && echo ${MYSQL_AUTH_USR} > secrets/db_user.txt"
                        command3="echo 'SPRING_DATASOURCE_URL=jdbc:mysql://paymybuddydb:3306/db_paymybuddy' > env/paymybuddy.env && echo 'SPRING_DATASOURCE_PASSWORD=${MYSQL_AUTH_PSW}' >> env/paymybuddy.env && echo 'SPRING_DATASOURCE_USERNAME=${MYSQL_AUTH_USR}' >> env/paymybuddy.env"
                        command4="docker compose down && docker pull ${DOCKERHUB_AUTH_USR}/${IMAGE_NAME}:${IMAGE_TAG}"
                        command5="docker compose up -d"
                        ssh -t ubuntu@${HOSTNAME_DEPLOY_STAGING} \
                            -o SendEnv=IMAGE_NAME \
                            -o SendEnv=IMAGE_TAG \
                            -o SendEnv=DOCKERHUB_AUTH_USR \
                            -o SendEnv=DOCKERHUB_AUTH_PSW \
                            -o SendEnv=MYSQL_AUTH_USR \
                            -o SendEnv=MYSQL_AUTH_PSW \
                            -C "$command1 && $command2 && $command3 && $command4 && $command5"
                    '''
                }
            }
        }

        stage('Test Staging') {
            when {
                expression { GIT_BRANCH == 'origin/training' }
            }
            steps {
                sh '''
                    sleep 30
                    apk add --no-cache curl
                    curl ${HOSTNAME_DEPLOY_STAGING}
                '''
            }
        }

        stage ('Deploy in prod') {
            when {
                expression { GIT_BRANCH == 'origin/training' }
            }
            steps {
                sshagent(credentials: ['SSH_AUTH_SERVER']) { 
                    sh '''
                        [ -d ~/.ssh ] || mkdir ~/.ssh && chmod 0700 ~/.ssh
                        ssh-keyscan -t rsa,dsa ${HOSTNAME_DEPLOY_PROD} >> ~/.ssh/known_hosts
                        scp -r deploy ubuntu@${HOSTNAME_DEPLOY_PROD}:/home/ubuntu/
                        command1="cd deploy && echo ${DOCKERHUB_AUTH_PSW} | docker login -u ${DOCKERHUB_AUTH_USR} --password-stdin"
                        command2="echo 'IMAGE_VERSION=${DOCKERHUB_AUTH_USR}/${IMAGE_NAME}:${IMAGE_TAG}' > .env && echo ${MYSQL_AUTH_PSW} > secrets/db_password.txt && echo ${MYSQL_AUTH_USR} > secrets/db_user.txt"
                        command3="echo 'SPRING_DATASOURCE_URL=jdbc:mysql://paymybuddydb:3306/db_paymybuddy' > env/paymybuddy.env && echo 'SPRING_DATASOURCE_PASSWORD=${MYSQL_AUTH_PSW}' >> env/paymybuddy.env && echo 'SPRING_DATASOURCE_USERNAME=${MYSQL_AUTH_USR}' >> env/paymybuddy.env"
                        command4="docker compose down && docker pull ${DOCKERHUB_AUTH_USR}/${IMAGE_NAME}:${IMAGE_TAG}"
                        command5="docker compose up -d"
                        ssh -t ubuntu@${HOSTNAME_DEPLOY_PROD} \
                            -o SendEnv=IMAGE_NAME \
                            -o SendEnv=IMAGE_TAG \
                            -o SendEnv=DOCKERHUB_AUTH_USR \
                            -o SendEnv=DOCKERHUB_AUTH_PSW \
                            -o SendEnv=MYSQL_AUTH_USR \
                            -o SendEnv=MYSQL_AUTH_PSW \
                            -C "$command1 && $command2 && $command3 && $command4 && $command5"
                    '''
                }
            }
        }

        stage('Test Prod') {
            when {
                expression { GIT_BRANCH == 'origin/training' }
            }
            steps {
                sh '''
                    sleep 30
                    apk add --no-cache curl
                    curl ${HOSTNAME_DEPLOY_PROD}
                '''
            }
        }
    }

    post {
        success {
            slackSend (color: '#00FF00', message: "SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
        }
        failure {
            slackSend (color: '#FF0000', message: "FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
        }
    }

}
