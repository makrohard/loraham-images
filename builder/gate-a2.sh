#!/usr/bin/env bash
# loraham-images — Gate A2 + cold-reboot gate.
# Boots a THROWAWAY copy of the sealed image under systemd-nspawn --private-network,
# runs first boot in CI mode against genuine (namespaced) addresses, asserts the out-of-box
# journey, then reboots the completed image and asserts steady state. Never mutates the
# runner's host network namespace; the sealed published image is untouched.
#
# Usage: gate-a2.sh <sealed_raw_image> <variant>
# shellcheck shell=bash
set -o errexit -o nounset -o pipefail
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_repo="$(cd "$_here/.." && pwd)"
# shellcheck source=lib.sh
. "$_here/lib.sh"
require_root

SEALED="${1:?sealed image}"; VARIANT="${2:?variant}"
WORK="${WORK:-$_repo/work}"; OUT="${OUT:-$_repo/out}"
mkdir -p "$WORK" "$OUT/logs-$VARIANT"
COPY="$WORK/$VARIANT.gatea2.img"
ROOT="$WORK/mnt-a2"; mkdir -p "$ROOT"

# snapshot host netns to prove it is unchanged afterward
host_net_fp(){ ip -o addr show 2>/dev/null | awk '{print $2,$4}'; ip -o route show 2>/dev/null; }
HOST_BEFORE="$(host_net_fp)"

# MNT_ROOT/MNT_BOOT are read by lib.sh's detach_image/cleanup_image, not here.
# shellcheck disable=SC2034
mount_copy(){ attach_loop "$COPY"; mount "${LOOPDEV}p2" "$ROOT"; MNT_ROOT="$ROOT";
              mkdir -p "$ROOT/boot/firmware"; mount "${LOOPDEV}p1" "$ROOT/boot/firmware"; MNT_BOOT="$ROOT/boot/firmware"; }
group_begin "Gate A2: prepare throwaway copy + inject CI-only harness"
# Peak disk lands HERE, not at the one require_free before decompression: --reflink=auto gets
# no reflink on ext4, so this is a full second copy, and the throwaway is then grown by 2G.
# Report the budget early instead of failing as a late ENOSPC mid-boot.
require_free "$(dirname "$COPY")" $(( $(stat -c%s "$SEALED") + 2 * 1024*1024*1024 ))
cp --reflink=auto "$SEALED" "$COPY"
# Teardown on the way out uses lib.sh's best-effort cleanup_image (it must not mask the real
# failure); phase boundaries use the STRICT detach_image. A local duplicate of cleanup_image
# used to live here, which is what made "which detach is strict?" ambiguous.
trap 'set +e; cleanup_image; rm -f "$COPY"' EXIT

# Simulate the Pi's first-boot root expansion. On real hardware lhpc-growroot.service does this
# (growpart + resize2fs on a real block device); nspawn has no block device, so lhpc-growroot
# CI-skips (Gate B) and we grow the throwaway copy here instead, giving firstboot realistic room
# for device PKI etc. (the ENOSPC failure this guards against was found on real hardware).
log "growing throwaway copy (+2G) to simulate first-boot root expansion"
truncate -s +2G "$COPY"
attach_loop "$COPY"; parted -s "$COPY" resizepart 2 100%; detach_image
attach_loop "$COPY"; fsck_checked "${LOOPDEV}p2"; resize2fs "${LOOPDEV}p2"; detach_image

mount_copy

# CI-only: no real upstream in the private netns — don't let network-online wait-online hang the boot.
for wu in NetworkManager-wait-online.service systemd-networkd-wait-online.service; do
  ln -sf /dev/null "$ROOT/etc/systemd/system/$wu"
done

# CI substitute: nspawn cannot apply capability-bounding-set drops for NON-ROOT user services,
# so the hardened lhpc-web/lhpc-nginx units fail with 218/CAPABILITIES here (they start fine on
# real hardware). Relax ONLY those container-incompatible directives in the THROWAWAY copy — the
# released image keeps full hardening; real-boot hardening is verified on hardware (Gate B).
OP="$(sed -n 's/^OPERATOR_USER=//p' "$ROOT/etc/lhpc/image.env" | head -1)"; OP="${OP:-lhpc}"
for u in lhpc-web lhpc-nginx; do
  d="$ROOT/home/$OP/.config/systemd/user/$u.service.d"
  mkdir -p "$d"
  printf '[Service]\nProtectKernelModules=no\nProtectKernelTunables=no\nProtectControlGroups=no\n' \
    > "$d/10-ci-caps.conf"
done
chown -R --reference="$ROOT/home/$OP" "$ROOT/home/$OP/.config" 2>/dev/null || true

# CI env marker + firstboot drop-in to load it
printf 'LHPC_FIRSTBOOT_CI=1\n' > "$ROOT/etc/lhpc/ci.env"
mkdir -p "$ROOT/etc/systemd/system/lhpc-firstboot.service.d"
printf '[Service]\nEnvironmentFile=/etc/lhpc/ci.env\n' \
  > "$ROOT/etc/systemd/system/lhpc-firstboot.service.d/10-ci.conf"

# namespaced AP address + simulated upstream (created each boot, before firstboot)
cat > "$ROOT/usr/local/sbin/lhpc-ci-netsetup" <<'EOF'
#!/bin/sh
ip link add dummy-ap type dummy 2>/dev/null || true
ip addr add 10.42.0.1/24 dev dummy-ap 2>/dev/null || true
ip link set dummy-ap up 2>/dev/null || true
ip link add sim-up type dummy 2>/dev/null || true
ip addr add 192.168.50.10/24 dev sim-up 2>/dev/null || true
ip link set sim-up up 2>/dev/null || true
ip link set lo up 2>/dev/null || true
exit 0
EOF
chmod 0755 "$ROOT/usr/local/sbin/lhpc-ci-netsetup"
cat > "$ROOT/etc/systemd/system/lhpc-ci-netsetup.service" <<'EOF'
[Unit]
Description=CI-only namespaced AP/upstream addresses (Gate A2)
DefaultDependencies=no
Before=NetworkManager.service lhpc-firstboot.service network-pre.target sysinit.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/lhpc-ci-netsetup
[Install]
WantedBy=sysinit.target
EOF
mkdir -p "$ROOT/etc/systemd/system/sysinit.target.wants"
ln -sf ../lhpc-ci-netsetup.service "$ROOT/etc/systemd/system/sysinit.target.wants/lhpc-ci-netsetup.service"

# assertion program (mode from /etc/lhpc-gate-mode: firstboot | cold)
install -m0755 "$_here/ci-assert.sh" "$ROOT/usr/local/sbin/lhpc-ci-assert"
cat > "$ROOT/etc/systemd/system/lhpc-ci-assert.service" <<'EOF'
[Unit]
Description=CI-only Gate A2 assertions
After=lhpc-firstboot.service
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/lhpc-ci-assert
ExecStopPost=/bin/systemctl --no-block poweroff
TimeoutStartSec=900
StandardOutput=journal+console
[Install]
WantedBy=multi-user.target
EOF
ln -sf ../lhpc-ci-assert.service "$ROOT/etc/systemd/system/multi-user.target.wants/lhpc-ci-assert.service"

detach_image      # strict: the copy is booted next
group_end

boot_and_read(){ # $1 mode
  local mode="$1" res
  # Boot with --directory on the mounted copy (nspawn --image needs a GPT discoverable-partition
  # image; raspios is MBR). Keep it mounted so we read the result and logs directly afterwards.
  mount_copy
  printf '%s\n' "$mode" > "$ROOT/etc/lhpc-gate-mode"
  rm -f "$ROOT/var/lib/lhpc/gate-a2.result"
  group_begin "Gate A2: boot ($mode) under --private-network"
  set +e
  # --capability=all: same reason as the provisioning boot in build.sh — the guest runs a full
  # systemd and a non-root user manager that needs bounding-set capabilities it cannot obtain
  # here (218/CAPABILITIES). Trusted input, throwaway container, and this boot is additionally
  # confined to a private network namespace.
  SYSTEMD_NSPAWN_LOCK=0 timeout 1500 systemd-nspawn --directory="$ROOT" --boot --private-network \
      --capability=all --register=no --machine="lhpcgate$mode" --resolv-conf=off --timezone=off </dev/null
  set -e
  group_end
  res="$(cat "$ROOT/var/lib/lhpc/gate-a2.result" 2>/dev/null || echo MISSING)"
  cp -a "$ROOT/var/log/lhpc-firstboot.log" "$OUT/logs-$VARIANT/firstboot-$mode.log" 2>/dev/null || true
  cp -a "$ROOT/var/log/lhpc-ci-assert.log" "$OUT/logs-$VARIANT/assert-$mode.log" 2>/dev/null || true
  detach_image      # strict: another boot of the same copy follows
  log "gate ($mode) result: $res"
  [ "$res" = "PASS" ] || die "Gate A2 ($mode) failed: $res"
}

boot_and_read firstboot
boot_and_read cold

HOST_AFTER="$(host_net_fp)"
[ "$HOST_BEFORE" = "$HOST_AFTER" ] || die "runner host network namespace changed after Gate A2"
log "host netns unchanged after Gate A2"
log "GATE A2 + COLD-REBOOT: PASS"
