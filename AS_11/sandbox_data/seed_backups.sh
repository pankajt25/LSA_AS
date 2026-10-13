#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${DIR}/backups"
PROJ_DIR="${DIR}/test_project"

mkdir -p "$BACKUP_DIR" "$PROJ_DIR"

# Sample project contents
echo "server.port=8080" > "$PROJ_DIR/app.properties"
echo "database.url=jdbc:postgresql://db:5432/crm" > "$PROJ_DIR/db.conf"
echo "console.log('CRM Service running');" > "$PROJ_DIR/index.js"
mkdir -p "$PROJ_DIR/static"
echo "body { background: #0f172a; }" > "$PROJ_DIR/static/style.css"

# Archive 1: 2 days ago
tar -czf "$BACKUP_DIR/backup_prod_20261005_020000.tar.gz" -C "$DIR" test_project
touch -d "2 days ago" "$BACKUP_DIR/backup_prod_20261005_020000.tar.gz"

# Archive 2: 1 day ago
tar -czf "$BACKUP_DIR/backup_prod_20261006_020000.tar.gz" -C "$DIR" test_project
touch -d "1 day ago" "$BACKUP_DIR/backup_prod_20261006_020000.tar.gz"

# Archive 3 (Latest): Today
LATEST="$BACKUP_DIR/backup_prod_20261007_020000.tar.gz"
tar -czf "$LATEST" -C "$DIR" test_project
touch -d "now" "$LATEST"
(cd "$BACKUP_DIR" && sha256sum "$(basename "$LATEST")" > "$(basename "$LATEST").sha256")
