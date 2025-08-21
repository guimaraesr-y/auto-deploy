#!/bin/bash
set -e

# Formato do nome do arquivo de dump: dump_YYYY-MM-DD_HH-MM-SS.sql
FILENAME="dump_$(date +%Y-%m-%d_%H-%M-%S).sql"
DUMP_PATH="/dumps/$FILENAME"

echo "Iniciando dump do banco de dados para $DUMP_PATH"

# Executa o pg_dump usando variáveis de ambiente para autenticação
# PGHOST, PGUSER, PGPASSWORD, PGDATABASE serão fornecidas pelo docker-compose
/usr/local/bin/pg_dump -h $PGHOST -U $PGUSER -d $PGDATABASE -f $DUMP_PATH

echo "Dump concluído com sucesso."
