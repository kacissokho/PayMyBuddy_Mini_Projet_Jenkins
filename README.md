Objectif
Concevoir une pipeline CI/CD Jenkins qui :

garantit la qualité & sécurité du code (tests + SonarCloud),

package l’application (image Docker), publie l’image sur Docker Hub (traçabilité/artefact),

déploie automatiquement sur Heroku (staging puis production via promotion),

notifie l’équipe sur Slack du statut final.

Architecture d’exécution (vue d’ensemble)
GitHub (push/PR) → Webhook → Jenkins.

Jenkins (agents Docker)

Tests unitaires & d’intégration (Maven/JDK 17)

Analyse SonarCloud (Quality Gate)

Build JAR → docker build → tag

Push Docker Hub (artefact)

Push registry.heroku.com + release sur staging

Smoke tests staging

Promotion Heroku vers production (ou re-push)

Slack : notification du résultat.

Environnement & Outils
Jenkins LTS (Pipeline), agents Docker par étape.

Maven 3.9.x, JDK 17 (Spring Boot).

SonarCloud (analyse SaaS).

Docker & Docker Hub (stockage d’image).

Heroku CLI + Heroku Container Registry (2 apps : myapp-staging, myapp-prod).

Slack (plugin Jenkins ou webhook).

GitHub Webhooks.

Étapes de la pipeline (toutes sous agent Docker)
Tests automatisés

Exécuter tests unitaires et d’intégration (Surefire/Failsafe).

Vérification de la qualité de code

SonarCloud : analyse statique + Quality Gate.

Compilation & Packaging

Build du JAR (Maven) → docker build de l’image,

push sur Docker Hub (traçabilité),

push sur registry.heroku.com/<app>/web (déploiement Heroku).

Staging (Heroku)

container:release sur myapp-staging,

exécuter migrations si besoin, définir CONFIG VARS.

Tests de validation de déploiement (smoke)

Healthcheck /actuator/health, ping endpoints clés.

Production (Heroku)

Promotion staging → prod (atomique) ou re-push & release sur myapp-prod.

Notification Slack

Message récapitulatif (succès/échec, commit, lien run Jenkins).
