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
      steps {
        checkout scm
      }
    }

   stage('Maven go-offline (fast)') {
  agent {
    docker {
      image 'maven:3.9-eclipse-temurin-17'
      args '-v $HOME/.m2:/root/.m2'
    }
  }
  steps {
    catchError(buildResult: 'SUCCESS', stageResult: 'SUCCESS') {
      timeout(time: 3, unit: 'MINUTES') {
        sh '''
set -eu
mvn -B -ntp -DskipTests dependency:go-offline || true
'''
      }
    }
  }
}


    stage('SonarCloud analysis (fast)') {
      when {
        anyOf { branch 'master'; expression { env.GIT_BRANCH == 'origin/master' || env.BRANCH_NAME == 'master' } }
      }
      options { timeout(time: 4, unit: 'MINUTES') }
      agent { docker { image 'sonarsource/sonar-scanner-cli:latest' } }
      steps {
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
      post {
        always { script { currentBuild.result = 'SUCCESS' } }
      }
    }

    stage('Build image') {
      options { timeout(time: 25, unit: 'MINUTES') }
      agent any
      steps {
        sh '''
set -eux
docker build --pull --progress=plain -t ${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG} .
'''
      }
    }

    stage('Heroku: preparer & deployer STAGING') {
      when { expression { env.GIT_BRANCH == 'origin/master' || env.BRANCH_NAME == 'master' } }
      options { timeout(time: 20, unit: 'MINUTES') }
      agent any
      steps {
        sh '''
set -eux

# Login Heroku non interactif (fallback docker login si besoin)
heroku container:login || (echo "$HEROKU_API_KEY" | docker login --username=_ --password-stdin registry.heroku.com)

APP="${STAGING}"
heroku apps:info -a "$APP" >/dev/null 2>&1 || heroku create "$APP"
heroku stack:set container -a "$APP"

ensure_db() {
  local app="$1"
  local auto="${AUTO_PROVISION_JAWSDB}"
  local jurl
  jurl="$(heroku config:get JAWSDB_URL -a "$app" || true)"

  if [ -z "$jurl" ] && [ "$auto" = "true" ]; then
    echo "JawsDB absent sur $app -> provisioning..."
    heroku addons:create jawsdb:kitefin -a "$app" || true
    echo "Attente que JAWSDB_URL soit disponible..."
    for i in $(seq 1 24); do
      jurl="$(heroku config:get JAWSDB_URL -a "$app" || true)"
      [ -n "$jurl" ] && break
      echo "...pas encore pret (tentative $i/24)"
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

    stage('Test STAGING (HTTP 200)') {
      when { expression { env.GIT_BRANCH == 'origin/master' || env.BRANCH_NAME == 'master' } }
      options { timeout(time: 3, unit: 'MINUTES') }
      agent { docker { image 'curlimages/curl:8.8.0' } }
      steps {
        sh '''
set -eu
URL="https://paymybuddy-staging-ce7845d0d0a8.herokuapp.com/"
echo "Attente de stabilisation..."
sleep 30
CODE=$(curl -s -o /dev/null -w "%{http_code}" -L --retry 10 --retry-delay 3 "$URL")
if [ "$CODE" -ne 200 ]; then
  echo "STAGING: attendu 200, recu $CODE pour $URL"
  exit 1
fi
echo "STAGING OK (200): $URL"
'''
      }
    }

    stage('Heroku: preparer & deployer PROD') {
      when { expression { env.GIT_BRANCH == 'origin/master' || env.BRANCH_NAME == 'master' } }
      options { timeout(time: 20, unit: 'MINUTES') }
      agent any
      steps {
        sh '''
set -eux

heroku container:login || (echo "$HEROKU_API_KEY" | docker login --username=_ --password-stdin registry.heroku.com)

APP="${PRODUCTION}"
heroku apps:info -a "$APP" >/dev/null 2>&1 || heroku create "$APP"
heroku stack:set container -a "$APP"

ensure_db() {
  local app="$1"
  local auto="${AUTO_PROVISION_JAWSDB}"
  local jurl
  jurl="$(heroku config:get JAWSDB_URL -a "$app" || true)"

  if [ -z "$jurl" ] && [ "$auto" = "true" ]; then
    echo "JawsDB absent sur $app -> provisioning..."
    heroku addons:create jawsdb:kitefin -a "$app" || true
    echo "Attente que JAWSDB_URL soit disponible..."
    for i in $(seq 1 24); do
      jurl="$(heroku config:get JAWSDB_URL -a "$app" || true)"
      [ -n "$jurl" ] && break
      echo "...pas encore pret (tentative $i/24)"
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

    stage('Test PROD (HTTP 200)') {
      when { expression { env.GIT_BRANCH == 'origin/master' || env.BRANCH_NAME == 'master' } }
      options { timeout(time: 3, unit: 'MINUTES') }
      agent { docker { image 'curlimages/curl:8.8.0' } }
      steps {
        sh '''
set -eu
URL="https://paymybuddy-production-97c4996ae192.herokuapp.com/"
echo "Attente de stabilisation..."
sleep 30
CODE=$(curl -s -o /dev/null -w "%{http_code}" -L --retry 10 --retry-delay 3 "$URL")
if [ "$CODE" -ne 200 ]; then
  echo "PROD: attendu 200, recu $CODE pour $URL"
  exit 1
fi
echo "PROD OK (200): $URL"
'''
      }
    }
  }

  post {
    always {
      echo 'Pipeline termine.'
    }
  }
}
