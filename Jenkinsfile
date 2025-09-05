pipeline {
  agent none
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


  }

  stages {
    stage('Checkout') {
      agent any
      steps { checkout scm }
    }

    // --- LINTER: Java (Maven) ---
    // Exécute les linters Checkstyle/PMD/SpotBugs.
    // ⚠️ Requiert un projet Maven et les plugins maven correspondants dans le pom.xml
    stage('Lint') {
      agent { docker { image 'maven:3.9.8-eclipse-temurin-17' ; args '-v $HOME/.m2:/root/.m2' } }
      steps {
        sh '''
          set -eu
          mvn -B -DskipTests=true \
            checkstyle:check \
            pmd:check \
            com.github.spotbugs:spotbugs-maven-plugin:4.8.6.4:check
        '''
      }
    }

    // Build image Docker
    stage('Build image') {
      agent any
      steps {
        sh 'docker build -t ${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG} .'
      }
    }

    // --- SCAN SÉCURITÉ: Docker image (Trivy) ---
    // Échoue si vulnérabilités HIGH/CRITICAL détectées.
    stage('Security Scan (Docker image)') {
      agent { docker { image 'aquasec/trivy:0.55.1' } }
      steps {
        sh '''
          set -eu
          trivy image --quiet --no-progress \
            --severity CRITICAL,HIGH \
            --exit-code 1 \
            ${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}
        '''
      }
    }

    // --- QUALITÉ DE CODE: SonarQube + Quality Gate ---
    // Deux options selon tes plugins Jenkins:
    // 1) Sans plugin Sonar: on utilise le scanner CLI dans un conteneur.
    // 2) Si tu as le plugin "SonarQube Scanner for Jenkins", on attend le Quality Gate.
    stage('Code Quality (SonarQube)') {
      parallel {
        stage('Sonar Scan (CLI)') {
          agent { docker { image 'sonarsource/sonar-scanner-cli:5.0' } }
          steps {
            sh '''
              set -eu
              # Déduire des métadonnées si disponibles
              PROJECT_KEY="${IMAGE_NAME}"
              PROJECT_NAME="${IMAGE_NAME}"
              BRANCH_OPTS=""
              if [ -n "${BRANCH_NAME:-}" ]; then
                BRANCH_OPTS="-Dsonar.branch.name=${BRANCH_NAME}"
              fi

              sonar-scanner \
                -Dsonar.host.url="${SONAR_HOST_URL}" \
                -Dsonar.login="${SONAR_TOKEN}" \
                -Dsonar.projectKey="${PROJECT_KEY}" \
                -Dsonar.projectName="${PROJECT_NAME}" \
                -Dsonar.sources=./ \
                -Dsonar.java.binaries=./target/classes \
                ${BRANCH_OPTS}
            '''
          }
        }
        // Si tu as le plugin Sonar, cette sous-étape attendra le gate et peut interrompre le pipeline.
        stage('Quality Gate (si plugin installé)') {
          agent any
          when { expression { return Jenkins.instance.pluginManager.getPlugin('sonar') != null } }
          steps {
            script {
              withSonarQubeEnv('SonarQube') { echo 'Contexte SonarQube OK' }
              timeout(time: 10, unit: 'MINUTES') {
                // Nécessite "Quality Gates Plugin" + "SonarQube Scanner for Jenkins"
                def qg = waitForQualityGate()
                if (qg.status != 'OK') {
                  error "Quality Gate échoué: ${qg.status}"
                }
              }
            }
          }
        }
      }
    }

    // ----------------- Déploiements existants -----------------
    stage('Heroku:déployer STAGING') {
      when { expression { env.GIT_BRANCH == 'origin/master' || env.BRANCH_NAME == 'master' } }
      agent any
      steps {
        sh '''
set -eu
heroku container:login
APP="${STAGING}"
heroku apps:info -a "$APP" >/dev/null 2>&1 || heroku create "$APP"
heroku stack:set container -a "$APP"
ensure_db() {
  local app="$1"
  local auto="${AUTO_PROVISION_JAWSDB}"
  local jurl
  jurl="$(heroku config:get JAWSDB_URL -a "$app" || true)"
  if [ -z "$jurl" ] && [ "$auto" = "true" ]; then
    echo "JawsDB absent sur $app → provisioning…"
    heroku addons:create jawsdb:kitefin -a "$app" || true
    echo "Attente que JAWSDB_URL soit disponible…"
    for i in $(seq 1 24); do
      jurl="$(heroku config:get JAWSDB_URL -a "$app" || true)"
      if [ -n "$jurl" ]; then
        echo "JAWSDB_URL détectée."
        break
      fi
      echo "…pas encore prêt (tentative $i/24), on réessaie dans 5s"
      sleep 5
    done
  fi
  if [ -z "$jurl" ]; then
    echo "ERREUR: JAWSDB_URL est vide/inexistant sur $app. Abandon."
    exit 1
  fi
  local user pass host db
  user="$(echo "$jurl" | sed -E 's|mysql://([^:]+):([^@]+)@.*|\\1|')"
  pass="$(echo "$jurl" | sed -E 's|mysql://([^:]+):([^@]+)@.*|\\2|')"
  host="$(echo "$jurl" | sed -E 's|mysql://[^@]+@([^/]+)/.*|\\1|')"
  db="$(  echo "$jurl" | sed -E 's|.*/([^?]+).*|\\1|')"
  heroku config:set -a "$app" \
    SPRING_DATASOURCE_URL="jdbc:mysql://${host}/${db}?useSSL=false&serverTimezone=UTC" \
    SPRING_DATASOURCE_USERNAME="${user}" \
    SPRING_DATASOURCE_PASSWORD="${pass}" >/dev/null
}
ensure_db "$APP"
docker tag ${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG} registry.heroku.com/${APP}/web
docker push registry.heroku.com/${APP}/web
heroku container:release -a "$APP" web
heroku ps:scale web=1 -a "$APP" || true
heroku releases -a "$APP" | head -n 5
'''
      }
    }

    stage('Test STAGING') {
      when { expression { env.GIT_BRANCH == 'origin/master' || env.BRANCH_NAME == 'master' } }
      options { timeout(time: 2, unit: 'MINUTES') }
      agent { docker { image 'curlimages/curl:8.8.0' } }
      steps {
        sh 'curl -fsSL -o /dev/null -L  https://paymybuddy-staging-f24fd6eba824.herokuapp.com/login'
      }
    }

    stage('Heroku: déployer PROD') {
      when { expression { env.GIT_BRANCH == 'origin/master' || env.BRANCH_NAME == 'master' } }
      agent any
      steps {
        sh '''
set -eu
heroku container:login
APP="${PRODUCTION}"
heroku apps:info -a "$APP" >/dev/null 2>&1 || heroku create "$APP"
heroku stack:set container -a "$APP"
ensure_db() {
  local app="$1"
  local auto="${AUTO_PROVISION_JAWSDB}"
  local jurl
  jurl="$(heroku config:get JAWSDB_URL -a "$app" || true)"
  if [ -z "$jurl" ] && [ "$auto" = "true" ]; then
    echo "JawsDB absent sur $app → provisioning…"
    heroku addons:create jawsdb:kitefin -a "$app" || true
    echo "Attente que JAWSDB_URL soit disponible…"
    for i in $(seq 1 24); do
      jurl="$(heroku config:get JAWSDB_URL -a "$app" || true)"
      if [ -n "$jurl" ]; then
        echo "JAWSDB_URL détectée."
        break
      fi
      echo "…pas encore prêt (tentative $i/24), on réessaie dans 5s"
      sleep 5
    done
  fi
  if [ -z "$jurl" ]; then
    echo "ERREUR: JAWSDB_URL est vide/inexistant sur $app. Abandon."
    exit 1
  fi
  local user pass host db
  user="$(echo "$jurl" | sed -E 's|mysql://([^:]+):([^@]+)@.*|\\1|')"
  pass="$(echo "$jurl" | sed -E 's|mysql://([^:]+):([^@]+)@.*|\\2|')"
  host="$(echo "$jurl" | sed -E 's|mysql://[^@]+@([^/]+)/.*|\\1|')"
  db="$(  echo "$jurl" | sed -E 's|.*/([^?]+).*|\\1|')"
  heroku config:set -a "$app" \
    SPRING_DATASOURCE_URL="jdbc:mysql://${host}/${db}?useSSL=false&serverTimezone=UTC" \
    SPRING_DATASOURCE_USERNAME="${user}" \
    SPRING_DATASOURCE_PASSWORD="${pass}" >/devnull
}
ensure_db "$APP"
docker tag ${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG} registry.heroku.com/${APP}/web
docker push registry.heroku.com/${APP}/web
heroku container:release -a "$APP" web
heroku ps:scale web=1 -a "$APP" || true
heroku releases -a "$APP" | head -n 5
'''
      }
    }

    stage('Test Production') {
      when { expression { env.GIT_BRANCH == 'origin/master' || env.BRANCH_NAME == 'master' } }
      options { timeout(time: 2, unit: 'MINUTES') }
      agent { docker { image 'curlimages/curl:8.8.0' } }
      steps {
        sh 'curl -fsSL -o /dev/null -L https://paymybuddy-production-ced0cd4b464f.herokuapp.com/login'
      }
    }
  }

  post {
    success {
      slackSend channel: 'C09CTBMC74N', message: "SUCCES ${env.JOB_NAME} #${env.BUILD_NUMBER}"
    }
    failure {
      slackSend channel: 'C09CTBMC74N', message: "FAILLED ${env.JOB_NAME} #${env.BUILD_NUMBER}"
    }
  }
}
