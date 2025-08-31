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

## Étapes de la Pipeline CI/CD

                **A-La Partie CI:**
Les Etapes de la CD validées:

**![](https://github.com/kacissokho/PayMyBuddy/blob/master/.m2/CI_CD.png)**

## 🔄 Pipeline CI/CD – PayMyBuddy

Le pipeline Jenkins est composé de plusieurs étapes automatisées permettant de **construire, tester et déployer** l’application sur **Heroku**.  

### 1. ✅ Checkout
Récupère le code source depuis le dépôt Git afin d’avoir la dernière version du projet.  

### 2. 🏗️ Build image
Construit l’image Docker de l’application, nécessaire pour le déploiement et les tests.  

### 3. 🚀 Heroku: déployer STAGING
Déploie automatiquement l’image construite sur l’environnement **STAGING** de Heroku (préproduction).  

### 4. 🧪 Test STAGING
Exécute les tests automatisés sur l’environnement **STAGING** afin de vérifier le bon fonctionnement de l’application avant de passer en production.  

### 5. 🚀 Heroku: déployer PROD
Déploie l’application sur l’environnement **PRODUCTION** de Heroku si toutes les étapes précédentes se sont bien déroulées.  

### 6. 🔍 Test Production
Exécute un test simple sur l’environnement de **production** (ex. un `curl` pour vérifier l’accessibilité de l’application en ligne).  

### 7. 🏁 End
Marque la fin du pipeline.  
