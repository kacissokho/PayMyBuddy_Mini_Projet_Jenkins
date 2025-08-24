FROM amazoncorretto:17-alpine

# Installer git et maven (Alpine utilise apk)
RUN apk add --no-cache git maven

WORKDIR /app

COPY target/paymybuddy.jar /app/paymybuddy.jar

CMD ["java", "-jar", "paymybuddy.jar"]
