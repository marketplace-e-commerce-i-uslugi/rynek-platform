#!/bin/bash
# Punkt wejścia obrazu all-in-one: przygotowuje dane (przy pierwszym starcie) i oddaje sterowanie supervisordowi.
set -eu

DATA=/data
PG_BIN=/usr/local/pgbin
PGDATA="$DATA/postgres"

mkdir -p "$DATA/postgres" "$DATA/seaweed" "$DATA/opensearch" "$DATA/redis" /var/log/rynek /run/supervisor
chown -R postgres:postgres "$DATA/postgres"
chown -R opensearch:opensearch "$DATA/opensearch"
chown -R redis:redis "$DATA/redis"
chown -R root:root "$DATA/seaweed"
chmod 700 "$PGDATA"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "[rynek] Pierwszy start: tworzę bazy danych serwisów..."
  su postgres -c "$PG_BIN/initdb -D $PGDATA --auth=trust --encoding=UTF8 --locale=C.UTF-8" > /var/log/rynek/initdb.log
  su postgres -c "$PG_BIN/pg_ctl -D $PGDATA -o '-c listen_addresses=127.0.0.1' -w start" >> /var/log/rynek/initdb.log
  su postgres -c "psql -h 127.0.0.1 -v ON_ERROR_STOP=1 -f /opt/rynek/init-databases.sql" >> /var/log/rynek/initdb.log
  su postgres -c "$PG_BIN/pg_ctl -D $PGDATA -m fast -w stop" >> /var/log/rynek/initdb.log
fi

# Domyślne ustawienia oszczędnościowe JVM serwisów (nadpisz zmienną RYNEK_JAVA_OPTS, jeśli masz więcej pamięci).
export RYNEK_JAVA_OPTS="${RYNEK_JAVA_OPTS:--Xmx160m -Xss512k -XX:+UseSerialGC -XX:TieredStopAtLevel=1 -XX:MaxMetaspaceSize=128m -XX:ReservedCodeCacheSize=40m -XX:CICompilerCount=1}"

echo "[rynek] Start usług. Aplikacja będzie dostępna pod http://localhost:4200 za 1-3 minuty."
echo "[rynek] Stan usług: docker exec <kontener> supervisorctl -c /etc/supervisor/rynek.conf status | Logi: /var/log/rynek/<usługa>.log"
exec /usr/bin/supervisord -n -c /etc/supervisor/rynek.conf
