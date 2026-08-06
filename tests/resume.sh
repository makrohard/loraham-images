#!/usr/bin/env bash
# A corrected lhpc-config.txt must actually take effect on the next boot.
#
# run_step marks each step permanently done. Without a fingerprint, a box that failed partway
# and then had PASSWORD or HOSTNAME corrected would skip the already-done account/hostname steps
# and silently keep the OLD values — the same "I changed a setting and nothing happened" outcome
# that the parser's unknown-key rejection exists to prevent, reached through a different door.
#
# This drives the REAL parse+fingerprint block extracted from lhpc-firstboot.
# CFG and say() are consumed by the fingerprint block sourced at runtime; expect/refute run
# inside command substitution, which shellcheck reads as unreachable.
# shellcheck disable=SC2034,SC2317
set -o errexit -o nounset -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

FB=overlay/usr/local/sbin/lhpc-firstboot
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fails=0
expect(){ case "$3" in *"$2"*) echo "  ok: $1";; *) echo "  FAIL: $1 — want '$2' in '$3'"; fails=1;; esac; }
refute(){ case "$3" in *"$2"*) echo "  FAIL: $1 — '$2' should be absent"; fails=1;; *) echo "  ok: $1";; esac; }

# Extract the fingerprint block verbatim (between `parse_bootcfg` being called and the ov() helper).
awk '/^cfg_hash="none"/{p=1} p{print} /^printf .* "\$STATE\/config.hash"$/{if(p) exit}' "$FB" > "$TMP/fp.sh"
grep -q 'cfg_hash' "$TMP/fp.sh" || { echo "could not extract the fingerprint block"; exit 1; }

STATE="$TMP/state"; mkdir -p "$STATE"
# $1 = the CFG contents for this boot, as "KEY=VALUE" pairs
boot(){
  (
    say(){ echo "$*"; }
    declare -A CFG=()
    for kv in "$@"; do CFG["${kv%%=*}"]="${kv#*=}"; done
    # shellcheck source=/dev/null
    . "$TMP/fp.sh"
  )
}

echo "== firstboot resume: a changed lhpc-config.txt re-runs the steps =="

# boot 1: some steps completed, then a later one failed
out="$(boot "PASSWORD=first" "HOSTNAME=shack")"
touch "$STATE/account.done" "$STATE/hostname.done"
refute "first boot does not clear anything" "clearing step markers" "$out"

# boot 2: nothing changed — completed steps must stay done, or every reboot redoes everything
out="$(boot "PASSWORD=first" "HOSTNAME=shack")"
refute "unchanged config keeps the markers" "clearing step markers" "$out"
[ -f "$STATE/account.done" ] && echo "  ok: markers survive an unchanged boot" \
  || { echo "  FAIL: markers cleared with no config change"; fails=1; }

# boot 3: the operator corrects the password — the fix must apply
out="$(boot "PASSWORD=corrected" "HOSTNAME=shack")"
expect "corrected config clears the markers" "clearing step markers" "$out"
[ -f "$STATE/account.done" ] && { echo "  FAIL: account.done survived a config change"; fails=1; } \
  || echo "  ok: account step will re-run"

# boot 4: after clearing, the new fingerprint is the baseline again
touch "$STATE/account.done"
out="$(boot "PASSWORD=corrected" "HOSTNAME=shack")"
refute "the corrected config is the new baseline" "clearing step markers" "$out"

# --- the PKI marker must survive a config change ---------------------------------------------
# `lhpc webserver init` EXITS 1 over an existing PKI (recreating the CAs is destructive), so if a
# config-change rerun replayed device_pki the box would loop forever. Guarding with
# `webserver verify` was wrong: that command also validates nginx config, the console unit and the
# exposure plan, so a first attempt that died at expose/console would fail it WITH the PKI present
# and run init anyway. The marker is the honest predicate for "we already made a PKI".
echo "== device_pki.done survives a config change; other markers do not =="
rm -f "$STATE"/*.done "$STATE/config.hash"
boot "PASSWORD=first" >/dev/null
touch "$STATE/device_pki.done" "$STATE/account.done" "$STATE/console.done"
out="$(boot "PASSWORD=corrected")"
expect "a changed config still clears the markers" "clearing step markers" "$out"
[ -f "$STATE/device_pki.done" ] && echo "  ok: device_pki.done preserved (no second init, no loop)" \
  || { echo "  FAIL: device_pki.done was deleted — the rerun would hit the init refusal"; fails=1; }
[ -f "$STATE/account.done" ] && { echo "  FAIL: account.done survived, correction would not apply"; fails=1; } \
  || echo "  ok: account.done cleared, so the correction re-runs"

# --- PKI creation and its marker are not atomic ----------------------------------------------
# A power cut between `webserver init` and run_step's `touch` leaves CA material with no marker.
# A plain init then refuses forever (verified against the real CLI: exit 1), so the marker-absent
# path uses --confirm-recreate. Only a SUCCESSFUL attempt writes the marker.
echo "== an interrupted PKI attempt is recoverable on the next boot =="
pk="$TMP/pki"; mkdir -p "$pk/bin"; rm -f "$pk/material" "$STATE/device_pki.done"
cat > "$pk/bin/lhpc" <<'STUB'
#!/bin/sh
case "$*" in
  *"--confirm-recreate"*) touch "$PKI_MATERIAL"; exit 0 ;;           # always allowed
  "webserver init"*) [ -f "$PKI_MATERIAL" ] && exit 1 || { touch "$PKI_MATERIAL"; exit 0; } ;;
esac
exit 0
STUB
chmod +x "$pk/bin/lhpc"
awk '/^step_device_pki\(\)/{p=1} p{print} /^}/{if(p) exit}' "$FB" > "$pk/step.sh"
pki_boot(){
  ( say(){ :; }; fail(){ echo "FAILED: $*"; exit 1; }
    VARIANT=lite; HOSTNAME_FINAL=shack; AP_ADDR=10.42.0.1
    lhpc(){ PKI_MATERIAL="$pk/material" PATH="$pk/bin:$PATH" command lhpc "$@"; }
    # shellcheck source=/dev/null
    . "$pk/step.sh"
    step_device_pki && touch "$STATE/device_pki.done" )
}
touch "$pk/material"          # interrupted attempt: material present, marker absent
out="$(pki_boot 2>&1 || true)"
refute "marker-absent retry over leftover material succeeds" "FAILED" "$out"
[ -f "$STATE/device_pki.done" ] && echo "  ok: only the successful attempt wrote the marker" \
  || { echo "  FAIL: marker not written after a successful init"; fails=1; }

# --- completion is interruption-safe and durable -----------------------------------------------
# Redaction must precede .firstboot-done (an interruption between them would otherwise leave the
# credentials in plaintext on the FAT partition forever, with the unit condition guaranteeing
# nothing returns). That ordering strands a box unless completion is guarded, so $FINALIZING says
# "every step already succeeded, just finish". The transaction spans TWO filesystems, so each
# transition is flushed; and on Lite the radio must be handed back before completion is declared,
# or a "completed" box keeps advertising the recovery SSID.
echo "== an interrupted completion finishes, durably, without replaying anything =="
awk '/^complete_firstboot\(\)/{p=1} p{print} /^}/{if(p) exit}' "$FB" > "$TMP/complete.sh"

# $1 = boot-config contents, $2 = WIFI_MODE. Fresh directory per case: sharing one let an earlier
# case's .firstboot-done satisfy a later assertion, so the later case could not fail.
finish(){
  local d; d="$TMP/fin.$RANDOM"; mkdir -p "$d"
  ( DONE="$d/.firstboot-done"; FINALIZING="$d/.finalizing"; BOOTCFG="$d/lhpc-config.txt"
    WIFI_MODE="${2:-}"; CI="${CI:-0}"; LOG="$d/order"
    say(){ :; }; fail(){ echo "FAILED: $*"; exit 1; }
    systemctl(){ :; }
    sync(){ echo sync >> "$LOG"; }
    nmcli(){ echo "nmcli $*" >> "$LOG"; }
    printf '%s\n' "$1" > "$BOOTCFG"; touch "$FINALIZING"
    # shellcheck source=/dev/null
    . "$TMP/complete.sh"; complete_firstboot || exit 1
    printf 'done=%s finalizing=%s cfg=%s order=%s\n' \
      "$([ -f "$DONE" ] && echo yes || echo no)" \
      "$([ -f "$FINALIZING" ] && echo yes || echo no)" \
      "$(tr '\n' ' ' < "$BOOTCFG")" "$(tr '\n' ',' < "$LOG")" )
}

out="$(finish 'PASSWORD=secret1' || true)"
expect "unredacted config is redacted on recovery" "PASSWORD=REDACTED" "$out"
expect "completion is marked done"                 "done=yes"          "$out"
expect "finalizing marker is cleared"              "finalizing=no"     "$out"
expect "each transition is flushed"                "sync,sync,sync,sync" "$out"

out="$(finish 'PASSWORD=REDACTED' || true)"
expect "re-entry over an already-redacted config completes" "done=yes"          "$out"
expect "and stays redacted"                                 "PASSWORD=REDACTED" "$out"

# Lite: the recovery profile must go and the normal AP come up BEFORE completion is declared.
out="$(finish 'PASSWORD=REDACTED' ap || true)"
expect "recovery profile deleted"      "nmcli connection delete lhpc-recovery-ap" "$out"
# Order matters: a failed activation must leave the rescue network up, so `up lhpc-ap` comes first.
expect "normal AP activated BEFORE the rescue profile is removed" \
       "nmcli connection up lhpc-ap,nmcli connection down lhpc-recovery-ap" "$out"
expect "and only then marked done"     "done=yes"                                 "$out"
refute "non-AP variants touch no radio" "nmcli" "$(finish 'PASSWORD=REDACTED' client || true)"
# CI has no wlan0 and step_ap does not activate there either — the handback must not try.
refute "CI mode touches no radio" "nmcli" "$(CI=1 finish 'PASSWORD=REDACTED' ap || true)"

[ "$fails" -eq 0 ] && echo "RESUME TESTS PASSED" || { echo "RESUME TESTS FAILED"; exit 1; }
