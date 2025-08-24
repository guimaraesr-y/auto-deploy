#!/usr/bin/env bash
set -euo pipefail
set -x

# Entrypoint do pg-anon-scheduler
# Espera variáveis via ENV:
#  - PGHOST (padrao: db-replica)
#  - PGDATABASE (paymentproject)
#  - PGUSER (replicator)
#  - PGPASSWORD
#  - INTERVAL_SECONDS (3600 por default)
#  - RETENTION_COUNT (mantem N arquivos, default 168 -> ~7 dias se hourly)
#  - MASKING_RULES (path dentro do container, default /masks/masking_rules.sql)
#  - DUMP_DIR (default /dumps)
# Logs no stdout/stderr.

PGHOST="${PGHOST:-db-replica}"
PGDATABASE="${PGDATABASE:-paymentproject}"
PGUSER="${PGUSER:-replicator}"
PGPASSWORD="${PGPASSWORD:-replicator_password}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-3600}"
RETENTION_COUNT="${RETENTION_COUNT:-168}"
MASKING_RULES="${MASKING_RULES:-/masks/masking_rules.sql}"
DUMP_DIR="${DUMP_DIR:-/dumps}"

export PGHOST PGDATABASE PGUSER PGPASSWORD

# paths de binários (garante encontrar pg_dump e anon.sh)
PG_DUMP_BIN="/usr/lib/postgresql/17/bin/pg_dump"
PG_RESTORE_BIN="/usr/lib/postgresql/17/bin/pg_restore"
PG_CTL_BIN="/usr/lib/postgresql/17/bin/pg_ctl"
PSQL_BIN="/usr/lib/postgresql/17/bin/psql"

# sanity checks
if [ ! -x "$PG_DUMP_BIN" ]; then
  echo "[ERROR] pg_dump not found at $PG_DUMP_BIN. Exiting." >&2
  exit 2
fi

if [ ! -x "$PG_CTL_BIN" ]; then
  echo "[ERROR] pg_ctl not found at $PG_CTL_BIN. Exiting." >&2
  exit 2
fi

mkdir -p "$DUMP_DIR"
# chown -R "$(id -u):$(id -g)" "$DUMP_DIR" || true

echo "[pg-anon] Starting scheduler. Interval: ${INTERVAL_SECONDS}s. Dump dir: ${DUMP_DIR}"

load_masking_rules () {
  # apply masking rules
  "$PSQL_BIN" -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$MASKING_RULES" || {
    echo "[pg-anon] Failed to apply masking rules" >&2
    return 2
  }
}

#Função para fazer setup do banco anon
do_setup () {
  echo "[pg-anon] Starting setup for anon database"
  "$PG_CTL_BIN" start -w

  # drop/create database on local host
  PGPASSWORD="$POSTGRES_PASSWORD" "$PSQL_BIN" -h localhost -U "$POSTGRES_USER" -d postgres -c "DROP DATABASE IF EXISTS \"$POSTGRES_DB\";" || {
    echo "[pg-anon] Failed to drop existing anon DB" >&2
    return 2
  }
  PGPASSWORD="$POSTGRES_PASSWORD" "$PSQL_BIN" -h localhost -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE \"$POSTGRES_DB\";" || {
    echo "[pg-anon] Failed to create anon DB" >&2
    return 2
  }
  
  # Carrega a lib
  PGPASSWORD="$POSTGRES_PASSWORD" "$PSQL_BIN" -h localhost -U "$POSTGRES_USER" -d postgres -c "ALTER DATABASE \"$POSTGRES_DB\" SET session_preload_libraries = 'anon';" || {
    echo "[pg-anon] Failed to drop existing anon DB" >&2
    return 2
  }

  # setup anon database
  PGPASSWORD="$POSTGRES_PASSWORD" "$PSQL_BIN" -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /anon_setup.sql || {
    echo "[pg-anon] Failed to setup anon database" >&2
    return 2
  }
}

# função para fazer teardown do banco anon
do_teardown () {
  echo "[pg-anon] Starting teardown for anon database"

  PGPASSWORD="$POSTGRES_PASSWORD" "$PSQL_BIN" -h localhost -U "$POSTGRES_USER" -d postgres -c "DROP DATABASE IF EXISTS \"$POSTGRES_DB\"" || {
    echo "[pg-anon] Failed to teardown anon database" >&2
    return 2
  }

  "$PG_CTL_BIN" stop || {
    echo "[pg-anon] pg_ctl stop failed" >&2
    return 2
  }
}

# Função que gera um único dump anonimizado
do_run () {
  TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
  TMP_OUT="${DUMP_DIR}/paymentproject_anon_${TIMESTAMP}.sql.tmp"
  FINAL_OUT="${DUMP_DIR}/paymentproject_anon_${TIMESTAMP}.sql"

  echo "[pg-anon] Starting anon database"

  do_setup || {
    echo "[pg-anon] Failed to setup anon database" >&2
    return 2
  }

  echo "[pg-anon] Starting anon dump at ${TIMESTAMP} (host=${PGHOST})"

  # tenta conectar; se falhar, faz retry por um curto periodo antes de abortar esta rodada
  if ! pg_isready -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" -t 3 >/dev/null 2>&1; then
    echo "[pg-anon] Host $PGHOST not ready. Skipping this iteration."
    return 1
  fi

  # faz dump do banco de dados original
  "$PG_DUMP_BIN" --host "$PGHOST" --username "$PGUSER" --format=custom \
    --file="$TMP_OUT" --no-owner --no-acl "$PGDATABASE"

  # aguarda o local DB estar pronto
  if ! PGPASSWORD="$POSTGRES_PASSWORD" pg_isready -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t 3 >/dev/null 2>&1; then
    echo "[pg-anon] LOCALHOST DB not ready. Skipping this iteration."
    rm -f "$TMP_OUT"
    return 1
  fi

  # copia dump para o localhost db
  "$PG_RESTORE_BIN" --host localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --no-acl "$TMP_OUT" || {
    echo "[pg-anon] Failed to restore dump" >&2
    return 2
  }

  # carrega as regras de anonimização
  load_masking_rules || {
    echo "[pg-anon] Failed to load masking rules" >&2
    return 2
  }

  # anonimiza o banco
  "$PSQL_BIN" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT anon.anonymize_database()" || {
    echo "[pg-anon] Failed to apply anon rules" >&2
    return 2
  }

  # dump do banco anonimizado
  # (não necessariamente precisa, pre-prod pode ler deste banco)
  "$PG_DUMP_BIN" --host localhost --username "$POSTGRES_USER" --format=custom \
    --file="$FINAL_OUT" --no-owner --no-acl \
    "$POSTGRES_DB"

  rm -f "$TMP_OUT"

  # rotacionar: manter apenas as últimas RETENTION_COUNT
  if [ "${RETENTION_COUNT:-0}" -gt 0 ]; then
    ls -1t "${DUMP_DIR}"/paymentproject_anon_*.sql 2>/dev/null | awk "NR>${RETENTION_COUNT}" | xargs -r rm -f -- || true
  fi

  do_teardown

  return 0
}

# loop infinito (rodar a primeira vez no start)
while true; do
  # rodada com timeout para evitar travar indefinidamente (opcional)
  if ! do_run; then
    echo "[pg-anon] Run finished with error (non-fatal). Will retry after interval."
  fi
  sleep "${INTERVAL_SECONDS}"
done
