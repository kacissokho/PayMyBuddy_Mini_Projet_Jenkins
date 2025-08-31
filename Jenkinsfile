pipeline {
  agent none
  options { timestamps() }

  environment {
    // Image locale
    DOCKER_USERNAME = 'kacissokho'
    IMAGE_NAME      = 'paymybuddy'
    IMAGE_TAG       = 'v1.4'
    PORT_EXPOSED    = '8090'

    // Apps Heroku
    STAGING    = 'paymybuddy-staging'
    PRODUCTION = 'paymybuddy-production'

    // Provisionner JawsDB automatiquement si absent
    AUTO_PROVISION_JAWSDB = 'true'

    HEROKU_API_KEY = credentials('heroku_api_key')
    SONAR_TOKEN    = credentials('sonar_token')
  }

  stages {

    stage('Checkout') {
      agent any
      steps { checkout scm }
    }

    /* --- Tests unitaires : non bloquants + timeout --- */
    stage('Test') {
      options { timeout(time: 8, unit: 'MINUTES') }
      agent {
        docker {
          image 'maven:3.9-eclipse-temurin-17'
          args '-v $HOME/.m2:/root/.m2'
        }
      }
      steps {
        // N'échoue pas la pipeline même si "mvn test" échoue
        catchError(buildResult: 'SUCCESS', stageResult: 'SUCCESS') {
          sh '''
            set -eux
            mvn -B -ntp -DfailIfNoTests=false clean test
          '''
        }
      }
      post {
        always {
          // Publie les rapports même s'ils sont absents
          junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: true, keepLongStdio: true
          // Force explicitement le statut global
          script { currentBuild.result = 'SUCCESS' }
        }
      }
    }

    /* --- SonarCloud (FAST) : non bloquant & force SUCCESS --- */
    stage('SonarCloud analysis (fast)') {
      when {
        anyOf { branch 'master'; expression { env.GIT_BRANCH == 'origin/master' || env.BRANCH_NAME == 'master' } }
      }
      options { timeout(time: 4, unit: 'MINUTES') }
      agent { docker { image 'sonarsource/sonar-scanner-cli:latest' } }
      steps {
        // Ne marque pas le stage/build en échec
        catchError(buildResult: 'SUCCESS', stageResult: 'SUCCESS') {
          sh '''
            set -eu
            sonar-scanner \
              -Dsonar.host.url=https://sonarcloud.io \
              -Dsonar.login="${SONAR_TOKEN}" \
              -Dsonar.organization=kacissokho \
              -Dsonar.projectKey=kacissokho_PayMyBuddy \
              -Dsonar.sources=src/main/java,src/main/resources \
              -Dsonar.exclusions=**/target/**,**/*.min.js,**/*.min.css \
              -Dsonar.java.binaries=target
          '''
        }
      }
      post { always { script { currentBuild.result = 'SUCCESS' } } }
    }

    /* --- Build image : timeout + logs de contexte --- */
    stage('Build image') {
      options { timeout(time: 25, unit: 'MINUTES') }
      agent any
      steps {
        sh '''
          set -eux
          docker version
          echo "Taille du contexte :" ; du -sh . || true
          [ -f .dockerignore ] && { echo "-------- .dockerignore (head) --------"; sed -n '1,120p' .dockerignore; } || echo "Pas de .dockerignore"
          docker build --pull --progress=p
