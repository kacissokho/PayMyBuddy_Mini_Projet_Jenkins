### PayMyBuddy Application

The PayMyBuddy application is a Java-based application that uses MySQL as its backend database. 

This project uses Docker and Docker Compose to define and orchestrate the environment.

### Requirements:

Install docker and docker compose

 Clone the application:
 git clone git@github.com:kacissokho/bootcamp-project-update.git

Move to the cloned repos: cd bootcamp-project-update/mini-projet-docker

### Build :

Build the image with the command: docker build -t paymybuddy:v1 . 

check the images with the command: docker images

**![](https://github.com/kacissokho/bootcamp-project-update/blob/master/images/image-20250726-102559.png)**

### Docker Registry
Deploy a private registry and store the built images in it.
**![](https://github.com/kacissokho/bootcamp-project-update/blob/master/images/image-20250726-112448.png)**

**![](https://github.com/kacissokho/bootcamp-project-update/blob/master/images/image-20250726-112540.png)**

**![](https://github.com/kacissokho/bootcamp-project-update/blob/master/images/image-20250726-112321.png)**

**![](https://github.com/kacissokho/bootcamp-project-update/blob/master/images/image-20250726-112223.png)**
###  Infrastructure As Code
Go to the directory where the docker-compose.yml is located. 
Run the docker-compose: docker-compose up -d to start the service

**![](https://github.com/kacissokho/bootcamp-project-update/blob/master/images/image-20250726-113057.png)**

**![](https://github.com/kacissokho/bootcamp-project-update/blob/master/images/image-20250726-115828.png)**

### Access Website:

**![](https://github.com/kacissokho/bootcamp-project-update/blob/master/images/image-20250726-115951.png)**

### Components:
paymybuddy: Java application running on amazoncorretto:17-alpine

paymybuddydb: MySQL database server, Stores users, transactions, and account details

### Networks
paymybuddynetwork: bridge type

### Volumes
db_paymybuddy: Persistent volume used by MySQL to store database data.

### Environment Variables
These variables are defined in the .env file:

SPRING_DATASOURCE_USERNAME: Username for the database connection

SPRING_DATASOURCE_PASSWORD: Password for the database connection

SPRING_DATASOURCE_URL: JDBC URL for connecting to the MySQL database

 #### Database Initialization:
  
The database schema is initialized using the initdb directory, which contains SQL scripts to set up    the required tables and initial data. 

