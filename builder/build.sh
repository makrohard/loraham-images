#!/usr/bin/env bash
# loraham-images — host-side build orchestrator (root, native arm64 runner).
# grow -> stage -> provision (nspawn --boot) -> verify marker -> disarm -> seal ->
# shrink -> Gate A2 (throwaway copy) -> compress -> size report.
#
# Usage: build.sh <variant>            (variant = lite | desktop)
# Env:   WORK=<dir> (default ./work), OUT=<dir> (default ./out), WORKFLOW_RUN_ID
# shellcheck shell=bash
set -o errexit -o nounset -o pipefail
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_repo="$(cd "$_here/.." && pwd)"
# shellcheck source=lib.sh
. "$_here/lib.sh"
require_root
assert_host_arm64
trap cleanup_image EXIT INT TERM   # tear down any loop/mount left by a failed phase

VARIANT="${1:?usage: build.sh <lite|desktop>}"
WORK="${WORK:-$_repo/work}"; OUT="${OUT:-$_repo/out}"
mkdir -p "$WORK" "$OUT"
CAP=2147483648   # 2 GiB GitHub Release single-asset cap

# ---- load config -----------------------------------------------------------
load_env "$_repo/config/onboarding-defaults.env"
load_env "$_repo/config/$VARIANT.env"
: "${BASE_STREAM:?}"; : "${GROW_MB:?}"; : "${OPERATOR_USER:?}"; : "${OPERATOR_PASSWORD:?}"

disk_report "$WORK"

# ---- resolve base + lhpc ---------------------------------------------------
group_begin "resolve base + lhpc"
read -r BASE_URL BASE_SHA256 < <("$_here/resolve-base.sh" "$BASE_STREAM")
log "resolved base: $BASE_URL"
log "resolved base sha256: $BASE_SHA256"
[ "${#BASE_SHA256}" -eq 64 ] || die "base sha256 looks like a placeholder: $BASE_SHA256"
LHPC_SHA="$("$_here/resolve-lhpc.sh" resolve)"
log "resolved lhpc main: $LHPC_SHA"
group_end

# ---- fetch + verify --------------------------------------------------------
group_begin "fetch + verify base"
XZ="$WORK/base.img.xz"
curl -fL --retry 3 --retry-delay 5 -o "$XZ" "$BASE_URL"
echo "$BASE_SHA256  $XZ" | sha256sum -c - || die "base sha256 verification failed"
log "base sha256 verified"
group_end

# ---- decompress + build-time growth ----------------------------------------
group_begin "decompress + grow"
IMG="$WORK/$VARIANT.img"
require_free "$WORK" $(( 12 * 1024*1024*1024 ))
xz -dc "$XZ" > "$IMG"; rm -f "$XZ"
log "grow: append ${GROW_MB} MiB sparse"
truncate -s "+${GROW_MB}M" "$IMG"
attach_loop "$IMG"
parted -s "$IMG" resizepart 2 100% || parted -s "$IMG" unit '%' resizepart 2 100
detach_image
attach_loop "$IMG"
fsck_checked "${LOOPDEV}p2"
resize2fs "${LOOPDEV}p2"
# verify geometry + free space
gsz="$(blockdev --getsize64 "${LOOPDEV}p2")"
log "grown p2 size: $gsz bytes"
detach_image
group_end

# ---- stage -----------------------------------------------------------------
group_begin "stage overlay + provisioning payload"
ROOT="$WORK/mnt"
attach_loop "$IMG"
mount_image "$ROOT"
"$_here/resolve-base.sh" --verify-mounted "$ROOT"
assert_guest_arm64 "$ROOT"

# overlay (firstboot + growroot programs + units + generated boot README later)
cp -a "$_repo/overlay/." "$ROOT/"
chmod 0755 "$ROOT/usr/local/sbin/lhpc-firstboot" "$ROOT/usr/local/sbin/lhpc-growroot"

# baked config for firstboot + provision
install -d -m0755 "$ROOT/etc/lhpc"
cp "$_repo/config/onboarding-defaults.env" "$ROOT/etc/lhpc/onboarding-defaults.env"
cat > "$ROOT/etc/lhpc/image.env" <<EOF
VARIANT=$VARIANT
BOOTSTRAP_GUI=${BOOTSTRAP_GUI:-}
WIFI_MODE=${WIFI_MODE:-ap}
EXPOSE_SCOPE=${EXPOSE_SCOPE:-none}
PROXY_MODE=${PROXY_MODE:-none}
SSH_ENABLE=${SSH_ENABLE:-off}
OPERATOR_USER=$OPERATOR_USER
OPERATOR_PASSWORD=$OPERATOR_PASSWORD
LHPC_RESOLVED_SHA=$LHPC_SHA
WORKFLOW_RUN_ID=${WORKFLOW_RUN_ID:-}
IMAGE_BUILD_COMMIT=${IMAGE_BUILD_COMMIT:-}
BASE_URL=$BASE_URL
BASE_SHA256=$BASE_SHA256
CONSOLE_PORT=${CONSOLE_PORT:-8443}
EOF

# boot-partition README + MOTD, rendered from the SINGLE source (no drift).
render_doc(){
  local src="$_repo/docs/first-steps.$VARIANT.src.md"
  [ -f "$src" ] || src="$_repo/docs/first-steps.lite.src.md"
  sed -e "s#@AP_SSID@#${AP_SSID_BASE:-lhpc}-<device-suffix>#g" \
      -e "s#@AP_PSK@#${AP_PSK:-lorahampi}#g" \
      -e "s#@AP_ADDR@#${AP_ADDR:-10.42.0.1}#g" \
      -e "s#@CONSOLE_PORT@#${CONSOLE_PORT:-8443}#g" \
      -e "s#@OPERATOR_USER@#${OPERATOR_USER}#g" \
      -e "s#@OPERATOR_PASSWORD@#${OPERATOR_PASSWORD}#g" \
      -e "s#@WIFI_COUNTRY@#${WIFI_COUNTRY:-DE}#g" \
      -e "s#@TIMEZONE@#${TIMEZONE:-Europe/Berlin}#g" \
      "$src"
}
render_doc > "$ROOT/boot/firmware/README.txt"
render_doc > "$ROOT/etc/motd"

# Wi-Fi power-save disable drop-in (§2.9) — Lite only (container never detects wifi).
if [ "${WIFI_POWERSAVE_DISABLE:-0}" = "1" ]; then
  install -d -m0755 "$ROOT/etc/NetworkManager/conf.d"
  cat > "$ROOT/etc/NetworkManager/conf.d/wifi-nopowersave.conf" <<'EOF'
# loraham-images: keep the Zero 2 W Wi-Fi AP alive under sustained load.
# Undo: remove this file and `systemctl restart NetworkManager`.
[connection]
wifi.powersave = 2
EOF
fi

# provisioning payload + build-only oneshot
install -m0755 "$_here/provision.sh" "$ROOT/usr/local/sbin/lhpc-provision"
cat > "$ROOT/etc/systemd/system/lhpc-provision.service" <<'EOF'
[Unit]
Description=loraham-images provisioning (BUILD-ONLY)
After=network-online.target systemd-user-sessions.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/lhpc-provision
ExecStopPost=/bin/systemctl --no-block poweroff
StandardOutput=journal+console
TimeoutStartSec=0
[Install]
WantedBy=multi-user.target
EOF
ln -sf ../lhpc-provision.service "$ROOT/etc/systemd/system/multi-user.target.wants/lhpc-provision.service"

# plain resolv.conf for the container (save original)
if [ -e "$ROOT/etc/resolv.conf" ] || [ -L "$ROOT/etc/resolv.conf" ]; then
  cp -a "$ROOT/etc/resolv.conf" "$ROOT/etc/resolv.conf.lhpc-orig" 2>/dev/null || true
  rm -f "$ROOT/etc/resolv.conf"
fi
printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > "$ROOT/etc/resolv.conf"

# masks (build-only). NB: do NOT mask lhpc-firstboot here — its unit lives in /etc (our overlay),
# so a /dev/null mask would OVERWRITE the real unit and disarm's rm would delete it. Instead it is
# simply left un-enabled during provisioning (no wants symlink yet) and armed in disarm.
for u in NetworkManager.service wpa_supplicant.service systemd-networkd.service ssh.service \
         systemd-timesyncd.service dphys-swapfile.service; do
  ln -sf /dev/null "$ROOT/etc/systemd/system/$u"
done

detach_image
group_end

# ---- provision (nspawn --boot, host netns) ---------------------------------
group_begin "provision (systemd-nspawn --boot)"
attach_loop "$IMG"
mount_image "$ROOT"
set +e
# --capability=all: the guest runs the upstream install path (apt, dpkg maintainer scripts,
# systemd inside the container) and a non-root user manager that needs bounding-set
# capabilities it cannot otherwise obtain here (218/CAPABILITIES). Narrowing this was tried
# and is not worth the fragility: the input is trusted — our own overlay plus a pinned,
# SHA-verified base — and the container is thrown away at the end of the job.
SYSTEMD_NSPAWN_LOCK=0 timeout 9000 systemd-nspawn --directory="$ROOT" --boot --register=no \
    --capability=all --machine=lhpcbuild --resolv-conf=off --timezone=off </dev/null
nspawn_rc=$?
set -e
log "nspawn exited rc=$nspawn_rc"
# copy provision log out (artifact) — even on failure
mkdir -p "$OUT/logs-$VARIANT"
cp -a "$ROOT/var/log/lhpc-provision.log" "$OUT/logs-$VARIANT/" 2>/dev/null || true
cp -a "$ROOT/var/log/"*.log "$OUT/logs-$VARIANT/" 2>/dev/null || true
cp -a "$ROOT/etc/lhpc-image.json" "$OUT/logs-$VARIANT/" 2>/dev/null || true
# marker is the pass criterion, NOT the exit code
[ -f "$ROOT/var/lib/lhpc/.provisioned" ] || { detach_image; die "provisioning marker absent — build failed"; }
log "provisioning marker present"
group_end

# ---- build-time assertion: AP DHCP/NAT deps present ------------------------
group_begin "assert AP DHCP/NAT deps present in sealed image"
chroot "$ROOT" dpkg -s dnsmasq-base >/dev/null 2>&1 || die "dnsmasq-base missing — AP client DHCP would fail"
if chroot "$ROOT" dpkg -s nftables >/dev/null 2>&1 || chroot "$ROOT" dpkg -s iptables >/dev/null 2>&1; then
  log "NAT backend present"
else
  die "no NAT backend (nftables/iptables) — NM shared NAT would fail"
fi
group_end

# ---- disarm (remove build payload/masks, restore resolv.conf, arm firstboot)
group_begin "disarm build scaffolding"
rm -f "$ROOT/etc/systemd/system/multi-user.target.wants/lhpc-provision.service"
rm -f "$ROOT/etc/systemd/system/lhpc-provision.service"
rm -f "$ROOT/usr/local/sbin/lhpc-provision"
BUILD_MASKS="NetworkManager.service wpa_supplicant.service systemd-networkd.service ssh.service \
             systemd-timesyncd.service dphys-swapfile.service"
for u in $BUILD_MASKS; do
  if [ -L "$ROOT/etc/systemd/system/$u" ] && [ "$(readlink "$ROOT/etc/systemd/system/$u")" = /dev/null ]; then
    rm -f "$ROOT/etc/systemd/system/$u"
  fi
done
# assert none of OUR masks remain (do not touch masks the base ships)
for u in $BUILD_MASKS; do
  if [ -L "$ROOT/etc/systemd/system/$u" ] && [ "$(readlink "$ROOT/etc/systemd/system/$u")" = /dev/null ]; then
    die "build-created mask still present: $u"
  fi
done
# restore resolv.conf
rm -f "$ROOT/etc/resolv.conf"
if [ -e "$ROOT/etc/resolv.conf.lhpc-orig" ] || [ -L "$ROOT/etc/resolv.conf.lhpc-orig" ]; then
  mv "$ROOT/etc/resolv.conf.lhpc-orig" "$ROOT/etc/resolv.conf"
fi
# arm firstboot for the real image (ensure the real unit is present, then enable it)
[ -f "$ROOT/etc/systemd/system/lhpc-firstboot.service" ] || die "lhpc-firstboot.service unit missing before arming"
mkdir -p "$ROOT/etc/systemd/system/multi-user.target.wants"
ln -sf ../lhpc-firstboot.service "$ROOT/etc/systemd/system/multi-user.target.wants/lhpc-firstboot.service"

# arm the early rootfs-grow oneshot (runs before firstboot; fail-closed, owns expansion)
[ -f "$ROOT/etc/systemd/system/lhpc-growroot.service" ] || die "lhpc-growroot.service unit missing before arming"
mkdir -p "$ROOT/etc/systemd/system/sysinit.target.wants"
ln -sf ../lhpc-growroot.service "$ROOT/etc/systemd/system/sysinit.target.wants/lhpc-growroot.service"
# Recovery access is armed alongside it but ordered BEFORE it and gated on nothing, so a
# fail-closed expansion cannot take SSH down with it (firstboot keeps its Requires=).
ln -sf ../lhpc-recovery.service "$ROOT/etc/systemd/system/sysinit.target.wants/lhpc-recovery.service"
# Fallback AP: after NM, gated on nothing, self-removing once firstboot completes.
ln -sf ../lhpc-recovery-ap.service "$ROOT/etc/systemd/system/multi-user.target.wants/lhpc-recovery-ap.service"

# SINGLE expansion owner: lhpc-growroot.service (above) does growpart+resize2fs itself and is
# ordered before the base swap setup. We deliberately DO NOT re-arm the base rpi-resize.service —
# it pulls systemd-growfs-root, and an unordered second resizer racing lhpc-growroot on the same
# live partition is a real hazard. Our nspawn build boot consumes+disables rpi-resize
# (ConditionFirstBoot self-disable), but make it DETERMINISTIC: explicitly unlink any enable
# symlink so it can never ship armed alongside lhpc-growroot (seal.sh also fails closed on it).
rm -f "$ROOT/etc/systemd/system/sysinit.target.wants/rpi-resize.service"
# systemd-networkd-wait-online only ever fails on this NetworkManager image (networkd is unused);
# mask it (symlink to /dev/null) so it stops surfacing as a failed unit at boot. NM provides
# network-online.target readiness via NetworkManager-wait-online, so this is safe.
ln -sf /dev/null "$ROOT/etc/systemd/system/systemd-networkd-wait-online.service"
log "masked systemd-networkd-wait-online.service (unused on NM; only ever fails)"
group_end

# ---- cleanup, then seal ----------------------------------------------------
# Cleanup runs BEFORE seal.sh so that "sealed" means FINAL. It used to run after, which left
# the private-key scan and every other invariant asserted against a filesystem that then
# changed. These are all deletions, so nothing unsafe shipped — but the seal should be the last
# thing that touches the image, or it is not a seal.
# clear apt caches / logs / history to shrink
chroot "$ROOT" apt-get clean 2>/dev/null || true
rm -rf "$ROOT/var/lib/apt/lists/"* "$ROOT/var/cache/apt/archives/"*.deb 2>/dev/null || true
find "$ROOT/var/log" -type f -exec truncate -s0 {} + 2>/dev/null || true
rm -f "$ROOT/root/.bash_history" "$ROOT/home/$OPERATOR_USER/.bash_history" 2>/dev/null || true
# first-boot state must be clean so firstboot actually runs
rm -rf "$ROOT/var/lib/lhpc/firstboot.d" "$ROOT/var/lib/lhpc/.firstboot-done" \
       "$ROOT/var/lib/lhpc/.firstboot-finalizing" "$ROOT/var/lib/lhpc/.provisioned"

"$_here/seal.sh" "$ROOT" "$OPERATOR_USER" "$OPERATOR_PASSWORD"
detach_image

# ---- shrink ----------------------------------------------------------------
"$_here/shrink.sh" "$IMG"

# ---- Gate A2 (throwaway copy of the sealed image) --------------------------
"$_here/gate-a2.sh" "$IMG" "$VARIANT"

# ---- compress + size report ------------------------------------------------
group_begin "compress + size report"
FINAL="$OUT/loraham-lhpc-$VARIANT.img.xz"
xz -9 -T0 -c "$IMG" > "$FINAL"
sz="$(stat -c%s "$FINAL")"
log "final compressed size: $sz bytes ($(numfmt --to=iec "$sz")) — cap $CAP ($(numfmt --to=iec "$CAP"))"
( cd "$OUT" && sha256sum "$(basename "$FINAL")" > "$(basename "$FINAL").sha256" )
echo "$sz" > "$OUT/$VARIANT.size"
if [ "$sz" -gt "$CAP" ]; then
  die "final $VARIANT asset $sz bytes EXCEEDS the 2 GiB cap ($CAP) — reduce transient data / improve build"
fi
group_end
log "BUILD OK: $FINAL ($sz bytes)"
