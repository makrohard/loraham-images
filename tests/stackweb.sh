#!/usr/bin/env bash
# loraham-images — first boot proxies NO stack page by default. Since LHPC 0.14.0 a page is per
# radio (`<stack>@<rid>`) and the image ships no radio list, so a stack proxy at first boot is
# refused and firstboot never completes. Runs the real step_stackweb with the shipped defaults
# against an lhpc stub that records every call.
set -o errexit -o nounset -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
echo "== firstboot: no stack page proxied by default =="
FB=overlay/usr/local/sbin/lhpc-firstboot
calls=""
lhpc(){ calls+="lhpc $*"$'\n'; }
say(){ printf '%s\n' "$*"; }
fail(){ echo "  fail: $*"; exit 1; }
eval "$(sed -n '/^step_stackweb(){/,/^}/p' "$FB")"
declare -F step_stackweb >/dev/null || { echo "  step_stackweb not found in $FB"; exit 1; }
# shellcheck disable=SC1091
. config/onboarding-defaults.env
export AP_CIDR=10.42.0.0/24
for PROXY_MODE in ap local; do
  calls=""
  out="$(step_stackweb)"; step_stackweb >/dev/null
  [ -z "$calls" ] || { echo "  PROXY_MODE=$PROXY_MODE: default config proxies a page:"; printf '    %s\n' "$calls"; exit 1; }
  grep -q 'no stack page proxied by default' <<<"$out" || { echo "  PROXY_MODE=$PROXY_MODE: the note is missing"; exit 1; }
  echo "  ok: PROXY_MODE=$PROXY_MODE proxies nothing and says so"
done
echo "== docs: 0.14.0 commands name the instance (<stack>@<rid>) =="
# A bare stack in `lhpc stack start|stop`, `lhpc webserver proxy` is refused by LHPC 0.14.0.
bad="$(grep -nE 'lhpc (stack (start|stop)|webserver proxy) (meshcom|meshtastic|meshcore|graywolf|reticulum)( |$|`)' \
        README.md README_DE.md docs/*.md || true)"
[ -z "$bad" ] || { echo "  bare stack names:"; printf '%s\n' "$bad" | sed 's/^/    /'; exit 1; }
echo "  ok"
