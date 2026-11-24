# syntax=docker/dockerfile:1
# Wspólny Dockerfile wszystkich serwisów Spring Boot i api-gateway.
# Kontekstem budowania jest folder serwisu (submoduł), a plik leży tutaj:
#   docker build -f docker/service.Dockerfile rynek-identity-service

FROM eclipse-temurin:25-jdk AS build
WORKDIR /src
COPY .mvn .mvn
COPY mvnw pom.xml ./
RUN chmod +x mvnw
# Zależności w osobnej warstwie: zmiana kodu nie pobiera ich od nowa.
RUN --mount=type=cache,target=/root/.m2 ./mvnw -B -q dependency:go-offline
COPY src src
RUN --mount=type=cache,target=/root/.m2 ./mvnw -B -q -DskipTests package \
    && cp target/*-SNAPSHOT.jar /app.jar

FROM eclipse-temurin:25-jre
RUN useradd --system --uid 10001 --no-create-home rynek
WORKDIR /app
COPY --from=build /app.jar app.jar
USER rynek
# Domyślnie oszczędnie (kilkanaście JVM na jednej maszynie). Nadpisz zmienną JAVA_TOOL_OPTIONS, jeśli masz więcej pamięci.
ENV JAVA_TOOL_OPTIONS="-Xmx256m -Xss512k -XX:+UseSerialGC -XX:TieredStopAtLevel=1"
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
