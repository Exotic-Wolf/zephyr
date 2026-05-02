#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
API_READY_URL="${API_READY_URL:-http://localhost:3000/v1/health/ready}"

ok() {
  printf "✅ %s\n" "$1"
}

warn() {
  printf "⚠️  %s\n" "$1"
}

section() {
  printf "\n%s\n" "$1"
}

printf "Zephyr dev status snapshot\n"
printf "Workspace: %s\n" "$ROOT_DIR"

section "Core Tools"
if command -v pnpm >/dev/null 2>&1; then
  ok "pnpm $(pnpm --version)"
else
  warn "pnpm missing"
fi

if command -v flutter >/dev/null 2>&1; then
  ok "$(flutter --version | head -n 1)"
else
  warn "flutter missing"
fi

if env -u npm_config_prefix zsh -lc 'export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH" && command -v pod >/dev/null'; then
  POD_VERSION="$(env -u npm_config_prefix zsh -lc 'export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH" && pod --version')"
  ok "cocoapods ${POD_VERSION}"
else
  warn "cocoapods (pod) missing"
fi

section "Docker / Postgres"
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    ok "docker engine reachable"
    if docker ps --format '{{.Names}}' | grep -q '^zephyr-postgres$'; then
      ok "zephyr-postgres container running"
    else
      warn "zephyr-postgres container not running"
    fi
  else
    warn "docker installed but daemon not reachable"
  fi
else
  warn "docker missing"
fi

section "API"
if curl -fsS "$API_READY_URL" >/tmp/zephyr-api-ready.json 2>/dev/null; then
  STORAGE="$(grep -o '"storage":"[^"]*"' /tmp/zephyr-api-ready.json | head -n 1 | cut -d ':' -f 2 | tr -d '"')"
  if [[ -n "$STORAGE" ]]; then
    ok "API ready at ${API_READY_URL} (storage=${STORAGE})"
  else
    ok "API ready at ${API_READY_URL}"
  fi
else
  warn "API not ready at ${API_READY_URL}"
fi

section "Flutter Devices"
if command -v flutter >/dev/null 2>&1; then
  DEVICE_LINES="$(flutter devices 2>/dev/null | grep -E '• (ios|android)' || true)"
  if [[ -n "$DEVICE_LINES" ]]; then
    ok "mobile-capable devices detected"
    printf "%s\n" "$DEVICE_LINES"
  else
    warn "no iOS/Android devices detected"
  fi
fi

rm -f /tmp/zephyr-api-ready.json
