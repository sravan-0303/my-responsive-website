# Build stage
FROM openjdk:11 as builder

WORKDIR /app
COPY . .
RUN chmod +x gradlew
RUN ./gradlew clean build -x test

# Runtime stage
FROM openjdk:11-jre-slim

WORKDIR /app

# Copy JAR from builder (Spring Boot creates an executable JAR)
COPY --from=builder /app/build/libs/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
