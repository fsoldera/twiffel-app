#!/usr/bin/env sh
set -eu

# Run from the repo root (joppling-app/).
sensor="${1:-all}"

run_lint() {
  printf '%s\n' "==> lint / typecheck (Flutter)"
  flutter analyze --no-fatal-infos
}

run_unit() {
  printf '%s\n' "==> unit tests (Flutter)"
  flutter test
}

run_typecheck() {
  printf '%s\n' "==> typecheck (backend TypeScript)"
  cd backend && npx tsc --noEmit && cd ..
}

case "$sensor" in
  unit)
    run_unit
    ;;
  lint)
    run_lint
    ;;
  typecheck)
    run_typecheck
    ;;
  integration|build)
    printf '%s\n' "[skip] $sensor: not configured (builds run via Codemagic)."
    ;;
  all)
    run_lint
    run_unit
    run_typecheck
    ;;
  *)
    printf '%s\n' "Unknown sensor: $sensor" >&2
    printf '%s\n' "Supported sensors: unit lint typecheck integration build all" >&2
    exit 1
    ;;
esac
