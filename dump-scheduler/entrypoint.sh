#!/usr/bin/env sh
set -euo pipefail
set -x

PGHOST="${PGHOST:-db-replica}"
PGDATABASE="${PGDATABASE:-paymentproject}"
PGUSER="${PGUSER:-replicator}"
PGPASSWORD="${PGPASSWORD:-replicator_password}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-3600}"
RETENTION_COUNT="${RETENTION_COUNT:-168}"
MASKING_RULES="${MASKING_RULES:-/masks/masking_rules.sql}"
DUMP_DIR="${DUMP_DIR:-/dumps}"

export PGHOST PGDATABASE PGUSER PGPASSWORD

if [ ! -x "$CONFIG_FILE" ]; then
  echo "[ERROR] config.txt not found at $PG_CTL_BIN. Exiting." >&2
  exit 2
fi

mkdir -p "$DUMP_DIR"

echo "[pg-anon] Starting scheduler. Interval: ${INTERVAL_SECONDS}s. Dump dir: ${DUMP_DIR}"

# Função que gera um único dump anonimizado
do_run () {
  TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
  FINAL_OUT="${DUMP_DIR}/paymentproject_anon_${TIMESTAMP}.sql"

  echo "[pg-anon] Starting anon database"

  echo "[pg-anon] Starting anon dump at ${TIMESTAMP} (host=${PGHOST})"

  # tenta conectar; se falhar, faz retry por um curto periodo antes de abortar esta rodada
  if ! pg_isready -t 3 >/dev/null 2>&1; then
    echo "[pg-anon] Host $PGHOST not ready. Skipping this iteration."
    return 1
  fi

  npx pg-anonymizer \
    -n \
    --config "${CONFIG_FILE}" \
    --output "${FINAL_OUT}" || {
    echo "[pg-anon] Anon dump failed. Skipping this iteration."
    return 1
  }

  # rotacionar: manter apenas as últimas RETENTION_COUNT
  if [ "${RETENTION_COUNT:-0}" -gt 0 ]; then
    ls -1t "${DUMP_DIR}"/paymentproject_anon_*.sql 2>/dev/null | awk "NR>${RETENTION_COUNT}" | xargs -r rm -f -- || true
  fi

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
