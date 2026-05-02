#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT_DIR/services/zephyr-api"
MOBILE_DIR="$ROOT_DIR/apps/zephyr-mobile"

API_BASE_URL="${API_BASE_URL:-http://localhost:3000}"
IOS_DEVICE_ID="${IOS_DEVICE_ID:-}"
SKIP_PODS="${SKIP_PODS:-0}"
KEEP_API="${KEEP_API:-0}"

API_PID=""

cleanup() {
  if [[ -n "$API_PID" && "$KEEP_API" != "1" ]]; then
    kill "$API_PID" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT INT TERM

printf "Starting local Postgres...\n"
pnpm --dir "$API_DIR" db:up

printf "Starting API (localdb mode)...\n"
nohup pnpm --dir "$API_DIR" start:dev:localdb >/tmp/zephyr-api-localdb.log 2>&1 &
API_PID="$!"

printf "Waiting for API readiness at %s/v1/health/ready ...\n" "$API_BASE_URL"
for _ in {1..45}; do
  if curl -fsS "$API_BASE_URL/v1/health/ready" >/dev/null 2>&1; then
    printf "API is ready.\n"
    break
  fi
  sleep 1
done

if ! curl -fsS "$API_BASE_URL/v1/health/ready" >/dev/null 2>&1; then
  printf "API did not become ready. Check /tmp/zephyr-api-localdb.log\n" >&2
  exit 1
fi

if [[ "$SKIP_PODS" != "1" ]]; then
  printf "Installing iOS pods...\n"
  env -u npm_config_prefix zsh -lc "export PATH=\"$HOME/.gem/ruby/2.6.0/bin:$PATH\" && cd \"$MOBILE_DIR/ios\" && pod install"
else
  printf "Skipping pod install because SKIP_PODS=1\n"
fi

printf "Launching Flutter app on iOS...\n"
if [[ -n "$IOS_DEVICE_ID" ]]; then
  (cd "$MOBILE_DIR" && flutter run -d "$IOS_DEVICE_ID" --dart-define="API_BASE_URL=$API_BASE_URL")
else
  (cd "$MOBILE_DIR" && flutter run --dart-define="API_BASE_URL=$API_BASE_URL")
fi
