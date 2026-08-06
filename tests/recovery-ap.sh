#!/usr/bin/env bash
# Drive the REAL lhpc-recovery-ap against a stubbed nmcli that keeps a profile store, so the
# persisted-profile cases are exercised rather than reasoned about.
#
# Both regressions here are lockout paths, not hygiene: this script only runs when first boot has
# NOT completed, and in the growroot-failure state firstboot never runs to repair anything. So a
# profile left in a bad state, or a fallback wrongly suppressed, is permanent on a Wi-Fi-only box.
#
# Assertions read the SCRIPT-UNDER-TEST's own output and the resulting profile STORE — never a
# log of attempted nmcli commands. The first version of this harness matched "up lhpc-recovery-ap"
# in such a log, which was written BEFORE the command ran, so it reported PASS while activation
# was actually failing (its unquoted heredoc had also turned `connection add` into `echo ""`).
set -o errexit -o nounset -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

SRC=overlay/usr/local/sbin/lhpc-recovery-ap
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fails=0
expect(){ case "$3" in *"$2"*) echo "  ok: $1";; *) echo "  FAIL: $1 — want '$2' in '$3'"; fails=1;; esac; }
refute(){ case "$3" in *"$2"*) echo "  FAIL: $1 — '$2' should be absent from '$3'"; fails=1;; *) echo "  ok: $1";; esac; }

# Fixed sandbox path: run() executes inside $( ), a subshell, so anything it assigned
# would not reach store() in the parent.
D="$TMP/run"
# $1 = pre-existing profile names (space separated), $2 = "modify-fails" to break `nmcli modify`
run(){
  rm -rf "$D"; mkdir -p "$D/bin" "$D/etc/lhpc" "$D/net"
  : > "$D/profiles"
  for p in ${1:-}; do echo "$p:partial" >> "$D/profiles"; done
  printf 'SSH_ENABLE=on\nWIFI_MODE=ap\nWIFI_COUNTRY=DE\n' > "$D/etc/lhpc/image.env"
  printf 'RECOVERY_SSID_BASE=lhpc-recovery\nAP_PSK=lorahampi\nAP_ADDR=10.42.0.1\nAP_PREFIX=24\n' \
    > "$D/etc/lhpc/onboarding-defaults.env"
  # QUOTED heredoc: nothing below is expanded by THIS script. The stub takes its store path and
  # failure mode from the environment, so no fragile substitution pass is needed.
  cat > "$D/bin/nmcli" <<'STUB'
#!/bin/sh
# Profiles are stored as "name:state" where state is partial|ok. Modelling CONFIGURATION state,
# not just existence, is what makes "repaired" distinguishable from "trusted": a half-configured
# leftover is exactly what an earlier failed `modify` leaves, and it must not activate.
case "$*" in
  *"connection show"*)   cut -d: -f1 "$NMCLI_STORE" ;;
  "connection delete "*) grep -v "^$3:" "$NMCLI_STORE" > "$NMCLI_STORE.n" 2>/dev/null || :
                         mv "$NMCLI_STORE.n" "$NMCLI_STORE" ;;
  "connection add "*)    echo "lhpc-recovery-ap:partial" >> "$NMCLI_STORE" ;;
  "connection modify "*) [ "${NMCLI_MODIFY_FAILS:-0}" = 1 ] && exit 1
                         sed -i "s/^$3:partial$/$3:ok/" "$NMCLI_STORE" ;;
  # Activation succeeds ONLY for a fully configured profile.
  "connection up "*)     grep -qx "$3:ok" "$NMCLI_STORE" || exit 1 ;;
esac
exit 0
STUB
  chmod +x "$D/bin/nmcli"
  printf '#!/bin/sh\nexit 0\n' > "$D/bin/iw"; chmod +x "$D/bin/iw"
  sed -e "s#/etc/lhpc/#$D/etc/lhpc/#g" -e "s#/var/lib/lhpc/#$D/var-lib/#g" \
      -e "s#/sys/class/net/wlan0#$D/net#" "$SRC" > "$D/ap.sh"
  NMCLI_STORE="$D/profiles" \
  NMCLI_MODIFY_FAILS="$([ "${2:-}" = modify-fails ] && echo 1 || echo 0)" \
    PATH="$D/bin:$PATH" sh "$D/ap.sh" 2>&1 || true
}
store(){ tr '\n' ' ' < "$D/profiles"; }
# case 1 seeds a PARTIAL leftover: activating it must be impossible without a repair.

echo "== recovery AP: persisted-profile handling =="

# 1. A half-configured leftover (add succeeded, modify failed on an earlier boot) must be
#    REPAIRED, not trusted. Trusting it meant activating an unusable profile forever.
out="$(run "lhpc-recovery-ap")"
expect "leftover recovery profile is recreated and activated" "recovery AP up:"  "$out"
expect "store holds exactly the recovery profile"             "lhpc-recovery-ap" "$(store)"

# 2. A stale lhpc-ap (firstboot created it, then failed before it worked) must NOT suppress the
#    fallback — existence is not evidence the real AP is usable, and firstboot replaces ours anyway.
out="$(run "lhpc-ap")"
expect "stale lhpc-ap does not suppress recovery" "recovery AP up:" "$out"

# 3. A failed modify must leave NO partial profile behind, and must not claim the AP is up.
out="$(run "" modify-fails)"
expect "failed modify reports the partial was removed" "partial profile removed" "$out"
refute "failed modify does not claim the AP is up"     "recovery AP up:"         "$out"
refute "and leaves no profile in the store"            "lhpc-recovery-ap"        "$(store)"

[ "$fails" -eq 0 ] && echo "RECOVERY-AP TESTS PASSED" || { echo "RECOVERY-AP TESTS FAILED"; exit 1; }
