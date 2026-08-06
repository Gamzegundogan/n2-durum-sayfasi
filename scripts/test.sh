#!/usr/bin/env bash
# Statik dosyaların ve konfigürasyonun temel doğruluğunu kontrol eder.
# CI'da build adımından ÖNCE çalışır; başarısızsa image üretilmez.
set -euo pipefail

fail=0

log() { echo "[$(date -u +%FT%TZ)] $*"; }

check() {
    local desc="$1"; shift
    if "$@"; then
        log "OK   - $desc"
    else
        log "FAIL - $desc"
        fail=1
    fi
}

check "site/index.html mevcut"      test -f site/index.html
check "site/style.css mevcut"       test -f site/style.css
check "nginx/default.conf mevcut"   test -f nginx/default.conf
check "Dockerfile mevcut"           test -f Dockerfile

check "index.html içinde <title> var" \
    grep -q "<title>" site/index.html

check "nginx config /healthz tanımlı" \
    grep -q "location = /healthz" nginx/default.conf

check "nginx config non-root port (8080) dinliyor" \
    grep -q "listen       8080" nginx/default.conf

check "Dockerfile non-root kullanıcı belirtiyor" \
    grep -Eq "^USER (101|nginx)" Dockerfile

check "Dockerfile 'latest' tag'e sabitlenmemiş base image kullanıyor" \
    grep -Eq "^FROM .+:[^ ]+" Dockerfile

if [ "$fail" -ne 0 ]; then
    log "Testlerden en az biri başarısız oldu."
    exit 1
fi

log "Tüm testler geçti."
exit 0
