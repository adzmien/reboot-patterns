FROM eclipse-temurin:21-jre
WORKDIR /app
# Single-stage image: copy the pre-built fat JAR produced by ./gradlew :patterns:p1-gateway:bootJar
COPY build/libs/p1-gateway*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
