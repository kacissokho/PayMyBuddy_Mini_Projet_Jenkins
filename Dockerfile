FROM amazoncorretto:17-alpine
WORKDIR /app
COPY target/paymybuddy.jar /app/paymybuddy.jar
EXPOSE 8080
CMD ["sh","-c","java -jar paymybuddy.jar --server.port=${PORT:-8080}"]
