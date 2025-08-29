# Runtime uniquement (léger)
FROM amazoncorretto:17-alpine

WORKDIR /app

# Copie n'importe quel jar buildé dans target/
COPY target/*jar /app/app.jar

# IMPORTANT pour Heroku : écouter le port assigné
# et supporter les flags mémoire depuis JAVA_OPTS si tu en as
CMD ["sh", "-c", "java $JAVA_OPTS -Dserver.port=$PORT -jar /app/app.jar"]
