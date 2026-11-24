#!/bin/bash
# Uruchamia jeden serwis Spring Boot w kontenerze all-in-one.
# Użycie: start-service.sh <nazwa> <opóźnienie_w_sekundach>
# Czeka na PostgreSQL (i na magazyn S3 dla media-service), a opóźnienie rozkłada start 17 JVM w czasie,
# żeby nie przeciążyć procesora.
set -u
name="$1"
delay="${2:-0}"

until pg_isready -q -h 127.0.0.1 -p 5432; do sleep 1; done

if [ "$name" = "media-service" ]; then
  until curl -s -o /dev/null http://127.0.0.1:8333; do sleep 1; done
fi

sleep "$delay"

# Mała pula połączeń i mało wątków: wystarczy do demonstracji, a oszczędza pamięć.
export SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE="${SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE:-3}"
export SPRING_DATASOURCE_HIKARI_MINIMUM_IDLE="${SPRING_DATASOURCE_HIKARI_MINIMUM_IDLE:-1}"
export SERVER_TOMCAT_THREADS_MAX="${SERVER_TOMCAT_THREADS_MAX:-16}"
export SPRING_MAIN_BANNER_MODE=off

exec java ${RYNEK_JAVA_OPTS} -jar "/opt/rynek/jars/${name}.jar"
