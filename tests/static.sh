#!/usr/bin/env bash
# loraham-images — local static tests (no root, no build). Run before pushing.
set -o errexit -o nounset -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "== bash -n (syntax) =="
scripts=(builder/*.sh overlay/usr/local/sbin/lhpc-firstboot tests/*.sh)
for f in "${scripts[@]}"; do bash -n "$f" && echo "  ok $f"; done

echo "== shellcheck =="
if command -v shellcheck >/dev/null 2>&1; then
  # SC1091: sourced files resolved at runtime; SC2154: vars from load_env/config;
  # SC2015: reviewed A&&B||C idioms (each C is the correct fallback in these spots).
  if shellcheck -x -e SC1091,SC2154,SC2015 "${scripts[@]}"; then
    echo "  shellcheck clean"
  else
    echo "  shellcheck FAILED"; exit 1
  fi
else
  echo "  shellcheck not installed — skipped"
fi

echo "== config sanity =="
for f in config/onboarding-defaults.env config/lite.env config/desktop.env; do
  grep -qE '^[A-Z_]+=' "$f" || { echo "  BAD $f"; exit 1; }
  # reject accidental shell metachars in values
  # shellcheck disable=SC2016
  if grep -nE '^[A-Z_]+=.*[`$(){}]' "$f"; then echo "  suspicious value in $f"; exit 1; fi
  # reject inline comments in a value (they silently become part of the value)
  if grep -nE '^[A-Z_]+=[^#]* #' "$f"; then echo "  inline comment in a value in $f (comments on their own line)"; exit 1; fi
  echo "  ok $f"
done
# AP key >= 8 chars (WPA2)
psk="$(sed -n 's/^AP_PSK=//p' config/onboarding-defaults.env)"
[ "${#psk}" -ge 8 ] || { echo "  AP_PSK '$psk' < 8 chars"; exit 1; }
echo "  AP_PSK length ok (${#psk})"

echo "== workflow present + arm64 pinned =="
grep -q 'runs-on: ubuntu-24.04-arm' .github/workflows/build-images.yml || { echo "  runner not arm64"; exit 1; }
grep -qE 'uses: [a-z-]+/[a-z-]+@[0-9a-f]{40}' .github/workflows/build-images.yml || { echo "  actions not SHA-pinned"; exit 1; }
echo "  ok"

echo "== docs: README lhpc-config example is clean (no inline comments users would copy) =="
# The boot-config parser strips ' #' comments, but the DOCUMENTED example must be copy-paste-safe.
if grep -nE '^[A-Z_]+=[^#]* #' README.md; then
  echo "  a KEY=VALUE line in README has an inline comment — users copy it verbatim into lhpc-config.txt"; exit 1
fi
echo "  ok"

echo "== real lhpc-config.txt parser test (valid / misspelled / invalid) =="
bash tests/parser.sh | sed 's/^/  /'

echo "ALL STATIC TESTS PASSED"
