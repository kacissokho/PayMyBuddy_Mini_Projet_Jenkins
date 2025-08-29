# ---- build ----
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /src
COPY pom.xml .
RUN mvn -B -q -DskipTests dependency:go-offline
COPY src ./src
RUN mvn -B -DskipTests package

# ---- runtime ----
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
COPY --from=build /src/target/*jar /app/app.jar
CMD ["sh", "-c", "java $JAVA_OPTS -Dserver.port=$PORT -jar /app/app.jar"]
