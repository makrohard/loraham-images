#!/usr/bin/env bash
# loraham-images — CI-only Gate A2 assertions, run INSIDE the throwaway container.
# Mode from /etc/lhpc-gate-mode: "firstboot" (after first boot) | "cold" (steady-state reboot).
# Writes PASS or "FAIL: <reason>" to /var/lib/lhpc/gate-a2.result, then the unit powers off.
set -o pipefail
LOG=/var/log/lhpc-ci-assert.log; exec > >(tee -a "$LOG") 2>&1
RESULT=/var/lib/lhpc/gate-a2.result; mkdir -p /var/lib/lhpc
MODE="$(cat /etc/lhpc-gate-mode 2>/dev/null || echo firstboot)"

# shellcheck disable=SC1091
. /etc/lhpc/image.env 2>/dev/null || true
. /etc/lhpc/onboarding-defaults.env 2>/dev/null || true
OP="${OPERATOR_USER:-lhpc}"; UID_OP="$(id -u "$OP" 2>/dev/null || echo 1000)"
XRD="/run/user/$UID_OP"; PORT="${CONSOLE_PORT:-8443}"
LHPC="/home/$OP/.local/bin/lhpc"; [ -x "$LHPC" ] || LHPC="$(command -v lhpc || echo lhpc)"
RUNTIME="/home/$OP/loraham-pi-control"   # assigned HERE, before any use (was used-before-assign)
as_op(){ runuser -u "$OP" -- env -u INVOCATION_ID HOME="/home/$OP" USER="$OP" LOGNAME="$OP" \
   XDG_RUNTIME_DIR="$XRD" DBUS_SESSION_BUS_ADDRESS="unix:path=$XRD/bus" \
   PATH="/home/$OP/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" "$@"; }

fail(){ echo "FAIL: $*"; echo "FAIL: $*" > "$RESULT"; exit 0; }
ok(){ echo "  ok: $*"; }

echo "=== ci-assert mode=$MODE variant=${VARIANT:-?} ==="

# Wait for first boot to COMPLETE (its durable marker). We cannot gate on
# is-system-running==running: this unit is part of the boot transaction, so the target isn't
# "running" until this unit finishes.
for _ in $(seq 1 150); do [ -f /var/lib/lhpc/.firstboot-done ] && break; sleep 2; done
if [ ! -f /var/lib/lhpc/.firstboot-done ]; then
  echo "  firstboot did NOT complete; log tail:"; tail -25 /var/log/lhpc-firstboot.log 2>/dev/null
  fail "firstboot did not complete (.firstboot-done missing)"
fi
ok "firstboot completed (state=$(systemctl is-system-running 2>/dev/null || echo '?'))"

# user manager + web units
for _ in $(seq 1 30); do [ -S "$XRD/bus" ] && break; sleep 1; done
[ -S "$XRD/bus" ] || fail "operator user bus absent"
systemctl is-active "user@$UID_OP.service" >/dev/null 2>&1 && ok "user manager active" || fail "user manager not active"
# wait for BOTH user units (nginx has ExecStartPre + Restart=on-failure, so it can lag lhpc-web,
# especially on the heavier Desktop cold boot)
for _ in $(seq 1 45); do as_op systemctl --user is-active lhpc-web.service   >/dev/null 2>&1 && break; sleep 2; done
for _ in $(seq 1 45); do as_op systemctl --user is-active lhpc-nginx.service >/dev/null 2>&1 && break; sleep 2; done
as_op systemctl --user is-active lhpc-web.service >/dev/null 2>&1 \
  || { as_op systemctl --user status lhpc-web.service --no-pager 2>&1 | tail -20; fail "lhpc-web user unit not active"; }
as_op systemctl --user is-active lhpc-nginx.service >/dev/null 2>&1 \
  || { as_op systemctl --user status lhpc-nginx.service --no-pager 2>&1 | tail -20; fail "lhpc-nginx user unit not active"; }
ok "web + nginx user units active"

# healthz + web GUI reachable
if [ "${VARIANT:-lite}" = "lite" ]; then ADDR="10.42.0.1"; else ADDR="127.0.0.1"; fi
HZ="https://$ADDR:$PORT/healthz"
for _ in $(seq 1 30); do curl -fsSk --max-time 5 "$HZ" | grep -q '"status"' && break; sleep 2; done
curl -fsSk --max-time 5 "$HZ" | grep -q '"status"' || fail "/healthz did not answer at $HZ"
ok "/healthz answers"
curl -fsSk --max-time 5 "https://$ADDR:$PORT/" | grep -qiE '<html|lhpc|console' || fail "web GUI did not load at $ADDR"
ok "web GUI loads"

# SSH policy: Lite exposes recovery SSH on ALL interfaces — a wired recovery path must survive a
# first-boot failure (an AP-only bind previously locked the operator out). Desktop keeps SSH off.
listeners="$(ss -H -tlnp 'sport = :22' 2>/dev/null | awk '{print $4}')"
if [ "${VARIANT:-lite}" = "lite" ]; then
  echo "$listeners" | grep -qE '(^0\.0\.0\.0:22$|^\*:22$|^\[::\]:22$)' \
    || fail "Lite recovery sshd not listening on all interfaces (got: ${listeners:-none})"
  ok "Lite recovery sshd on all interfaces"
else
  [ -z "$listeners" ] || fail "Desktop sshd should be off, but port 22 listens: $listeners"
  ok "Desktop sshd off"
fi

# no hardware + no stack running + daemon start refused
as_op "$LHPC" status > /tmp/st.txt 2>&1 || true
grep -qiE 'running=0|0 running|no radio hardware' /tmp/st.txt || echo "  (status head: $(head -3 /tmp/st.txt))"
out="$(as_op "$LHPC" stack start daemon --yes 2>&1 || true)"
echo "$out" | grep -qi 'no radio hardware configured' || fail "daemon start was NOT refused for want of hardware: $out"
ok "daemon start refused (no hardware)"
# make sure nothing actually started
as_op "$LHPC" status 2>&1 | grep -qiE '\brunning\b.*daemon|daemon.*\(running\)' && fail "a stack is running"
ok "no stack running"

# sole operator user — the base 'pi' placeholder must have been removed
others="$(getent passwd | awk -F: -v op="$OP" '$3>=1000 && $3<65534 && $1!=op {print $1"("$3")"}' | tr '\n' ' ')"
[ -z "$others" ] || fail "unexpected normal user(s) besides $OP: $others"
ok "sole operator user: $OP"

# callsign unset/default (empty or N0CALL) — read from the operator config. A missing local.toml
# means no operator callsign was ever set = default (pass); a missing RUNTIME dir is a real fault.
[ -d "$RUNTIME" ] || fail "runtime root $RUNTIME not found"
cs="$(grep -iE '^[[:space:]]*callsign[[:space:]]*=' "$RUNTIME/config/local.toml" 2>/dev/null | head -1 | sed -E 's/.*=[[:space:]]*//; s/["[:space:]]//g')"
if [ -z "$cs" ] || [ "$cs" = "N0CALL" ]; then ok "callsign unset/default (${cs:-empty})"; else fail "callsign is set to '$cs' (expected unset/N0CALL)"; fi

# fresh per-device PKI present
[ -s "$RUNTIME/config/tls/server/server.crt" ] && [ -s "$RUNTIME/config/tls/server/server.key" ] \
  || fail "device PKI (server cert/key) missing after firstboot"
ok "fresh device PKI present"

if [ "$MODE" = firstboot ]; then
  [ -f /var/lib/lhpc/.firstboot-done ] || fail "firstboot did not complete (.firstboot-done missing)"
  ok "firstboot completed"
  # idempotent re-invoke
  LHPC_FIRSTBOOT_CI=1 /usr/local/sbin/lhpc-firstboot || fail "firstboot re-invoke failed (not idempotent)"
  [ -f /var/lib/lhpc/.firstboot-done ] || fail "firstboot-done vanished on re-invoke"
  ok "firstboot idempotent on re-invoke"
  # swap transaction fixture — prove the mechanics on a controlled path. swapon is a host
  # resource the kernel refuses inside nspawn even with caps; that half is Gate B.
  T=/var/swap.citest
  fallocate -l 8M "$T" 2>/dev/null || dd if=/dev/zero of="$T" bs=1M count=8 status=none
  chmod 0600 "$T"
  mkswap "$T" >/dev/null || fail "swap fixture: mkswap failed"
  [ "$(stat -c '%a' "$T")" = 600 ] || fail "swap fixture: wrong mode"
  if swapon "$T" 2>/dev/null; then
    grep -q "^$T " /proc/swaps && ok "swap fixture incl live swapon" || fail "swap fixture: not in /proc/swaps"
    swapoff "$T"
  else
    ok "swap fixture: allocate+mkswap+mode ok (live swapon host-restricted in nspawn -> Gate B)"
  fi
  rm -f "$T"
else
  # cold-reboot steady state
  [ -f /var/lib/lhpc/.firstboot-done ] || fail "firstboot-done missing on cold reboot"
  systemctl is-active lhpc-firstboot.service 2>/dev/null | grep -qx active && fail "firstboot re-ran on cold boot"
  ok "firstboot stays disabled"
  if [ "${VARIANT:-lite}" = "lite" ]; then
    ac="$(nmcli -g connection.autoconnect connection show lhpc-ap 2>/dev/null || echo '')"
    [ "$ac" = "yes" ] || fail "AP profile autoconnect != yes (got '$ac')"
    ip -4 addr show | grep -q 'inet 10.42.0.1/' || fail "10.42.0.1 not owned on cold boot"
    ok "AP profile autoconnect + 10.42.0.1 owned"
  fi
fi

# no failed units — beyond known hardware/host units that cannot run in nspawn (Gate B, not here)
raw_failed="$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}')"
echo "  raw failed units: $(echo "$raw_failed" | tr '\n' ' ')"
real_failed=""
for u in $raw_failed; do
  case "$u" in
    apparmor.service|systemd-remount-fs.service|systemd-modules-load.service|\
    systemd-firstboot.service|fake-hwclock.service|e2scrub_reap.service|\
    rpi-eeprom-update.service|raspi-firmware.service|raspi-config.service|\
    rpi-resize*.service|rpi-set-swap*.service|rpi-setup-loop*.service|\
    systemd-zram-setup@*.service|dev-zram*.swap|*var-swap*.service|\
    *wait-online*|systemd-networkd*.service|ModemManager.service|userconfig.service)
      continue ;;
    *) real_failed="$real_failed $u" ;;
  esac
done
real_failed="$(echo "$real_failed" | xargs || true)"
[ -z "$real_failed" ] || fail "failed units (beyond container/hardware noise): $real_failed"
ok "no failed units beyond known container/hardware noise"

echo "PASS"; echo "PASS" > "$RESULT"
