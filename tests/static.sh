#!/usr/bin/env bash
# loraham-images — local static tests (no root, no build). Run before pushing.
set -o errexit -o nounset -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "== bash -n (syntax) =="
scripts=(builder/*.sh overlay/usr/local/sbin/lhpc-* tests/*.sh)
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

echo "== assets: mdview parses as python3 =="
# Shipped verbatim to /usr/local/bin/mdview on Desktop. It is the one non-shell program in the
# repo, so bash -n above does not cover it; a syntax error would only surface when a user clicks
# the README icon on a finished image.
# Unconditional: build.sh installs this file on every Desktop build, so its absence is a defect,
# not a reason for the gate to pass quietly.
[ -f assets/desktop/mdview ] || { echo "  assets/desktop/mdview is MISSING (build.sh installs it)"; exit 1; }
python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' assets/desktop/mdview \
  && echo "  ok assets/desktop/mdview" || { echo "  mdview FAILED to parse"; exit 1; }
head -1 assets/desktop/mdview | grep -q '^#!/usr/bin/env python3$' \
  || { echo "  mdview missing python3 shebang"; exit 1; }

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

bash tests/detach.sh || exit 1

echo "== device-suffix derivation is identical in both files =="
# lhpc-<sfx> (firstboot) and lhpc-recovery-<sfx> must name the SAME device. These two SUFFIX=
# lines are duplicated verbatim on purpose — a shared library for one line is worse — but they
# diverged once already (different source, different filter, 5 chars vs 4, uppercase dropped)
# and that is the string a user reads off a broken box. Compare them instead of trusting care.
a="$(grep -m1 '^SUFFIX=' overlay/usr/local/sbin/lhpc-firstboot)"
b="$(grep -m1 '^SUFFIX=' overlay/usr/local/sbin/lhpc-recovery-ap)"
[ -n "$a" ] && [ "$a" = "$b" ] || { echo "  SUFFIX= derivation differs between firstboot and recovery-ap:"; echo "    firstboot:   $a"; echo "    recovery-ap: $b"; exit 1; }
echo "  ok: both derive the suffix identically"

echo "== firstboot: hostname is set BEFORE the device PKI is generated =="
# LHPC bakes the hostname into its TLS SANs when it first generates its PKI, so a rename
# afterwards leaves the certificate permanently stale (repairing it needs a destructive CA
# re-init). The order already holds; this keeps it that way — the two steps are ~15 lines apart
# in a 600-line file and nothing else expresses the dependency.
_h="$(grep -n '^run_step hostname'   overlay/usr/local/sbin/lhpc-firstboot | cut -d: -f1)"
_p="$(grep -n '^run_step device_pki' overlay/usr/local/sbin/lhpc-firstboot | cut -d: -f1)"
{ [ -n "$_h" ] && [ -n "$_p" ] && [ "$_h" -lt "$_p" ]; } \
  || { echo "  hostname step (line ${_h:-?}) must run BEFORE device_pki (line ${_p:-?})"; exit 1; }
echo "  ok: hostname ($_h) precedes device_pki ($_p)"

bash tests/resume.sh || exit 1

bash tests/recovery-ap.sh || exit 1

echo "== real lhpc-config.txt parser test (valid / misspelled / invalid) =="
bash tests/parser.sh | sed 's/^/  /'

echo "ALL STATIC TESTS PASSED"
