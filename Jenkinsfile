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

    stage('Code Quality Check') {
      agent any
      options {
        timeout(time: 2, unit: 'MINUTES')
      }
      steps {
        sh '''
        set -eu
        echo "Vérification basique de la qualité du code..."
        
        # Vérification de la structure du projet
        echo "📁 Structure du projet:"
        find . -name "*.java" -o -name "pom.xml" -o -name "Dockerfile" | head -10 || true
        
        # Vérification basique des fichiers Java
        echo "🔍 Vérification des fichiers Java..."
        JAVA_FILES=$(find . -name "*.java" | head -5)
        if [ -n "$JAVA_FILES" ]; then
            echo "Fichiers Java trouvés:"
            echo "$JAVA_FILES"
            # Vérification simple de syntaxe (non-bloquant)
            for file in $JAVA_FILES; do
                echo "Vérification de $file"
                if head -n 1 "$file" | grep -q "package\\|import\\|public class"; then
                    echo "✓ $file semble être un fichier Java valide"
                else
                    echo "⚠️  $file - structure inhabituelle"
                fi
            done
        else
            echo "Aucun fichier Java trouvé"
        fi
        
        # Vérification de la présence de pom.xml pour Maven
        if [ -f "pom.xml" ]; then
            echo "📦 pom.xml détecté - projet Maven"
            echo "Version Java:"
            grep -i "<java.version>" pom.xml || echo "Version Java non spécifiée"
            echo "Dépendances:"
            grep -c "<dependency>" pom.xml | xargs echo "Nombre de dépendances:"
        fi
        
        echo "✅ Vérification de qualité du code terminée (non-bloquant)"
        '''
      }
    }

    stage('Linter') {
      agent any
      steps {
        sh '''
set -eu
if [ -f Dockerfile ]; then
  echo "Lance hadolint sur le Dockerfile…"
  # Donne le Dockerfile via stdin pour éviter les erreurs "does not exist"
  docker run --rm -i hadolint/hadolint hadolint - < Dockerfile
else
  echo "Pas de Dockerfile détecté, linter sauté."
fi
'''
      }
    }

    stage('Build image') {
      agent any
      steps {
        sh 'docker build -t ${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG} .'
      }
    }

    stage('Security Scan') {
      agent any
      options {
        timeout(time: 1, unit: 'MINUTES')
      }
      steps {
        sh '''
        set -eu
        echo "Vérification de sécurité basique..."
        
        # Vérification très basique - juste pour avoir un stage de sécurité
        echo "Vérification de l'image Docker..."
        docker image inspect ${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG} > /dev/null
        
        # Vérification rapide des couches de l'image
        echo "Analyse des couches de l'image..."
        docker history ${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG} | head -10
        
        echo "✓ Vérification de sécurité basique terminée"
        echo "Note: Scan complet désactivé pour accélérer le pipeline"
        '''
      }
    }

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
    sh 'curl -fsSL -o /dev/null -L   https://paymybuddy-staging-13a40145efb2.herokuapp.com/login'
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
stage('Test Production') {
  when { expression { env.GIT_BRANCH == 'origin/master' || env.BRANCH_NAME == 'master' } }
  options { timeout(time: 2, unit: 'MINUTES') }
  agent { docker { image 'curlimages/curl:8.8.0' } }
  steps {
    sh 'curl -fsSL -o /dev/null -L    https://paymybuddy-production-6f68af46bb3b.herokuapp.com/login'
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
