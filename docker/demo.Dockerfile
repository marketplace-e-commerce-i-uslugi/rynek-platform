# syntax=docker/dockerfile:1
# Rynek all-in-one (demo): cała platforma w jednym kontenerze.
# PostgreSQL, Redis, SeaweedFS, OpenSearch, api-gateway, 16 serwisów i frontend pod supervisordem.
# Kontekstem jest korzeń rynek-platform z pobranymi submodułami:
#   docker build -f docker/demo.Dockerfile -t rynek-demo .
#   docker run --rm -p 4200:4200 -p 8333:8333 -m 6g rynek-demo

# ---------- 1. Jary wszystkich serwisów ----------
FROM eclipse-temurin:25-jdk AS jars
WORKDIR /src
COPY . .
RUN --mount=type=cache,target=/root/.m2 <<'BUILD'
#!/bin/bash
set -eu
mkdir -p /jars
# Najpierw jedno wywołanie, które pobiera Maven Wrapper (równoległe pobieranie psuje cache).
(cd /src/rynek-api-gateway && chmod +x mvnw && ./mvnw -B -q -v)
# Cztery buildy Mavena naraz (wspólny cache ~/.m2).
ls -d rynek-api-gateway rynek-*-service | xargs -P 4 -I{} bash -c \
  'set -eu; cd /src/{}; chmod +x mvnw; ./mvnw -B -q -DskipTests package; cp target/*-SNAPSHOT.jar "/jars/$(echo {} | sed s/^rynek-//).jar"'
ls -l /jars
BUILD

# ---------- 2. Frontend ----------
FROM node:24-alpine AS web
WORKDIR /src
COPY rynek-frontend/package.json rynek-frontend/package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY rynek-frontend/ .
RUN npm run build

# ---------- 3. Obraz końcowy ----------
FROM eclipse-temurin:25-jre
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql redis-server nginx supervisor curl ca-certificates procps \
 && rm -rf /var/lib/apt/lists/* \
 && ln -s "$(ls -d /usr/lib/postgresql/*/bin | head -1)" /usr/local/pgbin \
 && useradd --system --shell /usr/sbin/nologin opensearch

# SeaweedFS (magazyn S3, statyczny plik wykonywalny) i OpenSearch (z własnym JDK).
COPY --from=chrislusf/seaweedfs:3.97 /usr/bin/weed /usr/local/bin/weed
COPY --from=opensearchproject/opensearch:2.19.1 --chown=opensearch:opensearch /usr/share/opensearch /opt/opensearch
RUN printf '%s\n' \
    'cluster.name: rynek' \
    'discovery.type: single-node' \
    'network.host: 127.0.0.1' \
    'http.port: 9200' \
    'path.data: /data/opensearch' \
    'path.logs: /var/log/rynek/opensearch' \
    'bootstrap.memory_lock: false' \
    'plugins.security.disabled: true' \
    > /opt/opensearch/config/opensearch.yml \
 && mkdir -p /var/log/rynek/opensearch && chown opensearch:opensearch /var/log/rynek/opensearch

COPY --from=jars /jars /opt/rynek/jars
COPY --from=web /src/dist/rynek-frontend/browser /usr/share/nginx/html
COPY rynek-infra/local/postgres/init/01-databases.sql /opt/rynek/init-databases.sql
COPY rynek-infra/local/seaweedfs/s3.json /opt/rynek/s3.json
COPY docker/demo/nginx.conf /opt/rynek/nginx.conf
COPY docker/demo/start-service.sh /opt/rynek/start-service.sh
COPY docker/demo/entrypoint.sh /opt/rynek/entrypoint.sh
COPY docker/demo/supervisord.conf /etc/supervisor/rynek.conf
RUN chmod +x /opt/rynek/*.sh

VOLUME /data
EXPOSE 4200 8333
# Adres 8333 (pliki: zdjęcia, awatary) przeglądarka otwiera bezpośrednio, więc też trzeba go opublikować.
HEALTHCHECK --interval=30s --timeout=5s --start-period=240s --retries=5 \
  CMD curl -fs http://127.0.0.1:8081/actuator/health > /dev/null && curl -fs http://127.0.0.1:4200/ > /dev/null || exit 1
ENTRYPOINT ["/opt/rynek/entrypoint.sh"]
