#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${DIR}/backups"
mkdir -p "$BACKUP_DIR"

create_backup() {
    local name="$1"
    local days_ago="$2"
    local size_k="$3"
    local fpath="${BACKUP_DIR}/${name}"
    
    # Generate realistic dummy archive data
    head -c "${size_k}K" /dev/urandom | gzip > "$fpath"
    touch -d "${days_ago} days ago" "$fpath"
    (cd "$BACKUP_DIR" && sha256sum "$name" > "${name}.sha256")
    touch -d "${days_ago} days ago" "${fpath}.sha256"
}

# Stale backups (> 7 days)
create_backup "backup_db_prod_20260907_020000.tar.gz" 30 250
create_backup "backup_db_prod_20260917_020000.tar.gz" 20 220
create_backup "backup_db_prod_20260923_020000.tar.gz" 14 310
create_backup "backup_db_prod_20260927_020000.tar.gz" 10 180

# Retained recent backups (<= 7 days)
create_backup "backup_db_prod_20261002_020000.tar.gz" 5 290
create_backup "backup_db_prod_20261004_020000.tar.gz" 3 240
create_backup "backup_db_prod_20261006_020000.tar.gz" 1 300
create_backup "backup_db_prod_20261007_020000.tar.gz" 0 320
