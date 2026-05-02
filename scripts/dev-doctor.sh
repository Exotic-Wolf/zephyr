#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

ok() {
  printf "✅ %s\n" "$1"
}

warn() {
  printf "⚠️  %s\n" "$1"
}

printf "Zephyr local dev doctor\n"
printf "Workspace: %s\n\n" "$ROOT_DIR"

if command -v pnpm >/dev/null 2>&1; then
  ok "pnpm: $(pnpm --version)"
else
  warn "pnpm missing"
fi

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    ok "docker engine reachable"
  else
    warn "docker installed but daemon not reachable"
  fi
else
  warn "docker missing"
fi

if command -v flutter >/dev/null 2>&1; then
  ok "flutter: $(flutter --version | head -n 1)"
else
  warn "flutter missing"
fi

if env -u npm_config_prefix zsh -lc 'export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH" && command -v pod >/dev/null'; then
  POD_VERSION="$(env -u npm_config_prefix zsh -lc 'export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH" && pod --version')"
  ok "cocoapods: ${POD_VERSION}"
else
  warn "cocoapods (pod) missing"
fi

if curl -fsS http://localhost:3000/v1/health/ready >/dev/null 2>&1; then
  ok "api health endpoint reachable on :3000"
else
  warn "api not reachable on :3000"
fi
