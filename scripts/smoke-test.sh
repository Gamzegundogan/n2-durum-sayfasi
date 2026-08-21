#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost:8080}"
fail=0

log() { echo "[$(date -u +%FT%TZ)] $*"; }

check_status() {
    local path="$1" expected="$2"
    local url="${BASE_URL}${path}"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" || echo "000")
    if [ "$code" = "$expected" ]; then
        log "OK   - GET $path -> $code"
    else
        log "FAIL - GET $path -> $code (beklenen: $expected)"
        fail=1
    fi
}

log "Smoke test başlıyor: $BASE_URL"

check_status "/" "200"
check_status "/healthz" "200"
check_status "/bu-yol-yok" "404"

if [ "$fail" -ne 0 ]; then
    log "Smoke test başarısız."
    exit 1
fi

log "Smoke test başarılı."
exit 0
