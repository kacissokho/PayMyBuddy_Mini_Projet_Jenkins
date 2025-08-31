# CI/CD Spring Boot → Heroku

🎯 Objectif  
Concevoir une pipeline CI/CD Jenkins qui :  

- récupère automatiquement le code source depuis GitHub ;  
- construit l’image Docker de l’application ;  
- déploie automatiquement sur **Heroku** (staging puis production) ;  
- exécute des tests de validation sur **STAGING** et **PRODUCTION** pour garantir la disponibilité.  

---

🧭 Architecture d’exécution (vue d’ensemble)  
Flux : GitHub (push/PR) → Webhook → Jenkins → Docker/Heroku  

**Détails côté Jenkins (agents Docker) :**  
1. **Checkout** → récupération du code source depuis GitHub  
2. **Build image** → construction de l’image Docker  
3. **Heroku: deploy STAGING** → push de l’image et release sur Heroku STAGING  
4. **Test STAGING** → exécution des tests fonctionnels (smoke tests) sur STAGING  
5. **Heroku: deploy PROD** → promotion/déploiement vers Heroku PRODUCTION  
6. **Test Production** → test basique (`curl`) pour vérifier l’accessibilité de l’application en ligne  

---

🧰 Environnement & Outils  
- Jenkins LTS (Pipeline), agents Docker par étape  
- Maven 3.9.x, JDK 17 (Spring Boot)  
- Docker (construction d’images locales)  
- Heroku CLI + Heroku Container Registry (2 apps : `paymybuddy-staging`, `paymybuddy-production`)  
- GitHub Webhooks (déclenchement automatique des builds)  



## 🔄 Pipeline CI/CD – PayMyBuddy

Le pipeline Jenkins est composé de plusieurs étapes automatisées permettant de **construire, tester et déployer** l’application sur **Heroku**.  

**![](https://github.com/kacissokho/PayMyBuddy/blob/master/.m2/CI_CD.png)**


### 1. ✅ Checkout
Récupère le code source depuis le dépôt Git afin d’avoir la dernière version du projet.  

### 2. 🏗️ Build image
Construit l’image Docker de l’application, nécessaire pour le déploiement et les tests.  

### 3. 🚀 Heroku: déployer STAGING
Déploie automatiquement l’image construite sur l’environnement **STAGING** de Heroku (préproduction).  

**![](https://github.com/kacissokho/PayMyBuddy/blob/master/.m2/paymybuddy-staging.png)**


### 4. 🧪 Test STAGING
Exécute les tests automatisés sur l’environnement **STAGING** afin de vérifier le bon fonctionnement de l’application avant de passer en production.  

### 5. 🚀 Heroku: déployer PROD
Déploie l’application sur l’environnement **PRODUCTION** de Heroku si toutes les étapes précédentes se sont bien déroulées.  

**![](https://github.com/kacissokho/PayMyBuddy/blob/master/.m2/paymybuddy-production.png)**


### 6. 🔍 Test Production
Exécute un test simple sur l’environnement de **production** (ex. un `curl` pour vérifier l’accessibilité de l’application en ligne).  

### 7. 🏁 End
Marque la fin du pipeline.  
