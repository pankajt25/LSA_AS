#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Stale files (> 7 days)
echo "stale session cache 14d" > "$DIR/session_cache_old.tmp"
touch -d "14 days ago" "$DIR/session_cache_old.tmp"

echo "stale worker thread log 10d" > "$DIR/worker_thread_stale.log"
touch -d "10 days ago" "$DIR/worker_thread_stale.log"

echo "stale crash dump 20d" > "$DIR/crash_dump_old.dmp"
touch -d "20 days ago" "$DIR/crash_dump_old.dmp"

echo "stale build artifact 30d" > "$DIR/build_artifact_expired.bin"
touch -d "30 days ago" "$DIR/build_artifact_expired.bin"

# Active / Fresh files (< 7 days)
echo "active user token 1d" > "$DIR/active_user_token.tmp"
touch -d "1 day ago" "$DIR/active_user_token.tmp"

echo "recent metrics today" > "$DIR/recent_metrics.log"
touch -d "now" "$DIR/recent_metrics.log"

echo "current session lock 2d" > "$DIR/current_session.lock"
touch -d "2 days ago" "$DIR/current_session.lock"

# Nested subdirectory
mkdir -p "$DIR/subcache"
echo "nested stale file 12d" > "$DIR/subcache/nested_stale.tmp"
touch -d "12 days ago" "$DIR/subcache/nested_stale.tmp"

echo "nested fresh file 3d" > "$DIR/subcache/nested_fresh.tmp"
touch -d "3 days ago" "$DIR/subcache/nested_fresh.tmp"
