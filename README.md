# CI/CD Spring Boot → Heroku (Jenkins + Docker + SonarCloud)

## 🎯 Objectif
Concevoir une pipeline **CI/CD Jenkins** qui :
- garantit la **qualité & sécurité** du code *(tests + SonarCloud)* ;
- **package** l’application *(image Docker)* et **publie** l’image sur **Docker Hub** *(traçabilité/artefact)* ;
- **déploie automatiquement** sur **Heroku** (*staging* puis *production* via promotion) ;
- **notifie** l’équipe sur **Slack** du **statut final**.

---

## 🧭 Architecture d’exécution (vue d’ensemble)
**Flux** : **GitHub (push/PR)** → **Webhook** → **Jenkins** → **Docker/Heroku** → **Slack**

**Détails côté Jenkins (agents Docker)** :
- **Build JAR → docker build → tag**  
- **Push Docker Hub** *(artefact)*  
- **Push** `registry.heroku.com` **+ release** sur **staging**  
- **Smoke tests** **staging**  
- **Promotion** Heroku vers **production** *(ou re-push)*  
- **Slack** : notification du résultat

---

## 🧰 Environnement & Outils
- **Jenkins LTS** (Pipeline), **agents Docker** par étape  
- **Maven 3.9.x**, **JDK 17** (Spring Boot)  
- **SonarCloud** (analyse SaaS)  
- **Docker & Docker Hub** (stockage d’image)  
- **Heroku CLI** + **Heroku Container Registry** *(2 apps : `myapp-staging`, `myapp-prod`)*  
- **Slack** (plugin Jenkins ou **webhook**)  
- **GitHub Webhooks**

---

## 🏗️ Étapes de la pipeline **

### 1) Tests automatisés
- Exécuter **tests unitaires** et **tests d’intégration** *(Surefire/Failsafe)*.

### 2) Vérification de la qualité de code
- **SonarCloud** : analyse statique + **Quality Gate**.

### 3) Compilation & Packaging
- **Build du JAR** *(Maven)* → **docker build** de l’image  
- **Push** sur **Docker Hub** *(traçabilité)*  
- **Push** sur `registry.heroku.com/<app>/web` *(déploiement Heroku)*

### 4) Staging (Heroku)
- `container:release` sur **`myapp-staging`**  
- Exécuter **migrations** si besoin, définir **CONFIG VARS**

### 5) Tests de validation de déploiement (smoke)
- Healthcheck **`/actuator/health`**, ping des endpoints clés

### 6) Production (Heroku)
- **Promotion** *staging → prod* *(atomique)* **ou** re-push & release sur **`myapp-prod`**

### 7) Notification Slack
- Message récapitulatif (**succès/échec**, **commit**, **lien du run Jenkins**)
