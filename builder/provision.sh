#!/usr/bin/env bash
# loraham-images — provisioning, runs INSIDE the booted nspawn container as root
# (as the lhpc-provision.service oneshot). Full systemd is PID 1 here, so lingering +
# `systemctl --user` work. Writes /var/lib/lhpc/.provisioned on success; the host build
# treats that MARKER (not the container exit code) as the pass criterion.
#
# Inputs via /etc/lhpc/image.env (written by the host): VARIANT, BOOTSTRAP_GUI,
# OPERATOR_USER, OPERATOR_PASSWORD, LHPC_RESOLVED_SHA, WORKFLOW_RUN_ID, BASE_URL, BASE_SHA256.
# shellcheck shell=bash
set -o errexit -o nounset -o pipefail

LOG=/var/log/lhpc-provision.log
exec > >(tee -a "$LOG") 2>&1
ts() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }
say() { printf '[%s] provision: %s\n' "$(ts)" "$*"; }
die() { printf '[%s] provision FATAL: %s\n' "$(ts)" "$*"; exit 1; }

# ---- load host-supplied image.env (KEY=VALUE, no sourcing) -----------------
IMG_ENV=/etc/lhpc/image.env
[ -f "$IMG_ENV" ] || die "missing $IMG_ENV"
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"; case "$line" in ''|'#'*) continue ;; esac
  key="${line%%=*}"; val="${line#*=}"
  case "$key" in [A-Z_][A-Z0-9_]*) printf -v "$key" '%s' "$val"; export "${key?}" ;; esac
done < "$IMG_ENV"

: "${VARIANT:?}"; : "${OPERATOR_USER:?}"; : "${OPERATOR_PASSWORD:?}"; : "${LHPC_RESOLVED_SHA:?}"
BOOTSTRAP_GUI="${BOOTSTRAP_GUI:-}"

# ---- 1. wait for DNS, then apt update + full-upgrade ------------------------
say "waiting for DNS"
for _ in $(seq 1 30); do getent hosts deb.debian.org >/dev/null 2>&1 && break; sleep 2; done
getent hosts deb.debian.org >/dev/null 2>&1 || die "no DNS/network in container"

export DEBIAN_FRONTEND=noninteractive

# In an nspawn container '/' is not a block device, so mkinitramfs cannot determine the
# root device and kernel/initramfs configuration fails. Keep the base's tested, consistent
# kernel+initrd+bootloader (the base is the latest official image) and neutralise
# update-initramfs during the upgrade; everything else still upgrades.
say "hold base kernel/bootloader/firmware; neutralise update-initramfs (container-safe upgrade)"
hold_pkgs="$(dpkg-query -W -f='${Package}\n' 2>/dev/null \
  | grep -E '^(linux-image|linux-headers|raspberrypi-kernel|raspberrypi-bootloader|raspi-firmware)' || true)"
if [ -n "$hold_pkgs" ]; then
  # shellcheck disable=SC2086
  apt-mark hold $hold_pkgs >/dev/null || die "apt-mark hold failed"
fi
if [ ! -e /usr/sbin/update-initramfs.distrib ]; then
  dpkg-divert --add --rename --divert /usr/sbin/update-initramfs.distrib /usr/sbin/update-initramfs >/dev/null \
    || die "dpkg-divert --add for update-initramfs failed"
  ln -sf /bin/true /usr/sbin/update-initramfs
fi

say "apt-get update"
apt-get update -y
say "apt-get full-upgrade (kernel held; update-initramfs neutralised)"
apt-get -y -o Dpkg::Options::=--force-confold full-upgrade
# finish configuring anything the earlier state left pending (fail-closed: the update-initramfs
# stub makes any initramfs trigger a no-op, so this must succeed).
dpkg --configure -a

# Restore the real update-initramfs WITHOUT regenerating (base initrd stays) — FAIL CLOSED: a
# botched restore that shipped /bin/true as update-initramfs would silently break the device's
# future kernel updates.
if [ -e /usr/sbin/update-initramfs.distrib ]; then
  rm -f /usr/sbin/update-initramfs
  dpkg-divert --remove --rename /usr/sbin/update-initramfs >/dev/null || die "dpkg-divert --remove failed"
fi
if dpkg-divert --list /usr/sbin/update-initramfs 2>/dev/null | grep -q .; then die "update-initramfs diversion not removed"; fi
if [ -L /usr/sbin/update-initramfs ]; then die "update-initramfs is still the /bin/true stub"; fi
[ -x /usr/sbin/update-initramfs ] || die "update-initramfs missing/not executable after restore"

# ---- 2. base tools + AP DHCP/NAT dependency (blocker fix) -------------------
# git/curl/ca-certificates are needed before bootstrap-deps installs them (we clone the
# repo to obtain bootstrap-deps.sh itself). NM ipv4.method shared needs dnsmasq + a NAT backend.
say "installing base tools (git curl ca-certificates python3-dev) + NM shared deps (dnsmasq-base + NAT backend)"
# python3-dev: non-GUI, lets the reticulum venv compile spidev/gpiod C extensions (arm64 wheels
# are not always published). GUI-only optional deps stay out (Lite headless).
apt-get install -y --no-install-recommends git curl ca-certificates python3-dev dnsmasq-base
# NAT backend: prefer nftables (Trixie default); iptables as the compatibility shim.
apt-get install -y --no-install-recommends nftables iptables || true

# ---- 3. operator account + groups ------------------------------------------
say "creating operator user '$OPERATOR_USER'"
if ! id "$OPERATOR_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$OPERATOR_USER"
fi
printf '%s:%s\n' "$OPERATOR_USER" "$OPERATOR_PASSWORD" | chpasswd
# sudo + hardware groups that exist on the base.
for g in sudo gpio spi i2c dialout plugdev audio video netdev render kmem; do
  getent group "$g" >/dev/null 2>&1 && usermod -aG "$g" "$OPERATOR_USER" || true
done
OP_UID="$(id -u "$OPERATOR_USER")"
say "operator uid=$OP_UID"

# Use the base's SUPPORTED first-user mechanism to mark the operator configured and
# suppress the first-run wizard (userconf-pi userconfig.service / desktop piwiz), instead
# of hardcoding a mask list. cancel-rename is what raspi-config itself calls.
say "first-user state before: $(getent passwd | awk -F: '$3>=1000 && $3<65534{print $1"("$3")"}' | tr '\n' ' ')"
if command -v cancel-rename >/dev/null 2>&1; then
  cancel-rename "$OPERATOR_USER" && say "cancel-rename ok (wizard suppressed)" || say "cancel-rename returned nonzero (continuing)"
else
  say "cancel-rename not present; disabling userconfig.service if it exists"
  systemctl disable userconfig.service 2>/dev/null || true
fi
# Remove the base's unconfigured placeholder user so the operator is the SOLE user.
if id pi >/dev/null 2>&1 && [ "$OPERATOR_USER" != pi ]; then
  say "removing base placeholder user 'pi'"
  loginctl terminate-user pi 2>/dev/null || true
  pkill -KILL -u pi 2>/dev/null || true
  userdel -rf pi 2>/dev/null || say "userdel pi returned nonzero (continuing)"
fi

# ---- 4. lingering BEFORE install.sh, wait for the user bus -----------------
say "enable-linger + wait for user bus"
loginctl enable-linger "$OPERATOR_USER"
XRD="/run/user/$OP_UID"
for _ in $(seq 1 30); do [ -S "$XRD/bus" ] && break; sleep 1; done
[ -S "$XRD/bus" ] || die "user bus $XRD/bus did not appear (user-systemd/lingering failed)"

# Helper: run a command as the operator with the full user-bus env, INVOCATION_ID unset
# (operator path, not the managed-unit path), via a login-ish session (positive sid).
as_op() {
  runuser -u "$OPERATOR_USER" -- env -u INVOCATION_ID \
    HOME="/home/$OPERATOR_USER" USER="$OPERATOR_USER" LOGNAME="$OPERATOR_USER" \
    XDG_RUNTIME_DIR="$XRD" DBUS_SESSION_BUS_ADDRESS="unix:path=$XRD/bus" \
    PATH="/home/$OPERATOR_USER/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    "$@"
}

# ---- 5. bootstrap-deps dry-run HARD GATE -----------------------------------
CLONE="/home/$OPERATOR_USER/loraham-pi-control-src"
say "clone loraham-pi-control (install.sh clones main itself; this copy is only for --dry-run/tooling)"
as_op git clone --quiet --depth 1 https://github.com/makrohard/loraham-pi-control.git "$CLONE"
BOOT="$CLONE/bootstrap-deps.sh"
[ -f "$BOOT" ] || die "bootstrap-deps.sh not found in clone"

say "bootstrap-deps.sh --dry-run (hard gate; Lite: any nonzero fails, exit 6 = GUI leaked)"
dry_rc=0
bash "$BOOT" --dry-run > /var/log/bootstrap-dryrun.log 2>&1 || dry_rc=$?
if [ "$dry_rc" -ne 0 ]; then
  cat /var/log/bootstrap-dryrun.log
  if [ "$VARIANT" = "lite" ]; then
    die "bootstrap-deps --dry-run failed (rc=$dry_rc) on Lite"
  elif [ "$dry_rc" -eq 6 ]; then
    say "dry-run rc=6 on Desktop (graphical packages expected with --with-gui) — continuing"
  else
    die "bootstrap-deps --dry-run failed (rc=$dry_rc) on Desktop — only exit 6 (GUI) is tolerated"
  fi
fi

# ---- 6. real bootstrap-deps ------------------------------------------------
say "bootstrap-deps.sh (real) --spi-mode soft-cs --operator-user $OPERATOR_USER --no-swapfile $BOOTSTRAP_GUI"
# shellcheck disable=SC2086
bash "$BOOT" --spi-mode soft-cs --operator-user "$OPERATOR_USER" --no-swapfile $BOOTSTRAP_GUI

# ---- 7. install.sh as the operator; assert resolved SHA --------------------
say "install.sh (documented path) as $OPERATOR_USER"
as_op bash "$CLONE/install.sh"
# Locate the installed controller checkout dynamically and read HEAD AS THE OWNER
# (git refuses "dubious ownership" if root reads another user's repo).
# shellcheck disable=SC2016  # $HOME must expand in the operator's shell, not here
INSTALLED_ROOT="$(as_op bash -lc 'find "$HOME/loraham-pi-control" -maxdepth 4 -type d -name .git -printf "%h\n" 2>/dev/null | grep -E "/loraham-pi-control$" | head -1')"
[ -n "$INSTALLED_ROOT" ] || die "could not locate the installed loraham-pi-control git checkout"
say "installed checkout: $INSTALLED_ROOT"
INSTALLED_SHA="$(as_op git -C "$INSTALLED_ROOT" rev-parse HEAD 2>/dev/null || true)"
say "installed HEAD=$INSTALLED_SHA resolved=$LHPC_RESOLVED_SHA"
if [ "$INSTALLED_SHA" != "$LHPC_RESOLVED_SHA" ]; then
  FRESH="$(git ls-remote https://github.com/makrohard/loraham-pi-control.git refs/heads/main | awk '{print $1}')"
  [ "$INSTALLED_SHA" = "$FRESH" ] || die "unexplained LHPC SHA mismatch: installed=$INSTALLED_SHA resolved=$LHPC_RESOLVED_SHA current=$FRESH"
  say "main advanced mid-job; installed matches current main"
fi

LHPC_BIN="/home/$OPERATOR_USER/.local/bin/lhpc"
[ -x "$LHPC_BIN" ] || LHPC_BIN="lhpc"

# ---- 7b. Lite GUI closure assertion ----------------------------------------
if [ "$VARIANT" = "lite" ]; then
  # Broader GUI/display/toolkit denylist (the --dry-run exit-6 gate above is the PRIMARY guard;
  # this catches anything that leaked despite it). Any present on a headless Lite = GUI leak.
  leaked="$(dpkg -l | awk '$1=="ii"{print $2}' | grep -E '^(libgtk-3-0|libgtk-4-1|libwayland-client0|libwayland-server0|x11-common|xserver-xorg-core|libqt5gui5|libqt6gui6|python3-tk|lightdm)(:|$)' | tr '\n' ' ' || true)"
  say "Lite GUI leak check: ${leaked:-none}"
  [ -z "$leaked" ] || die "GUI packages present on Lite: $leaked — GUI leaked into the closure"
fi

# ---- 8. auto-install (no --source/--tests/--tx) ----------------------------
# SPI/GPIO device-node substitutes for the BUILD only. Some source stacks gate a MANDATORY
# dep on a device node (reticulum: check_file=/dev/spidev0.0) that nspawn has no device tree
# to create. The venv build/test only IMPORTS spidev/gpiod, it never opens the device, so a
# placeholder lets the stack install+build. /dev is runtime devtmpfs — these never enter the
# sealed image; real SPI/GPIO operation is hardware Gate B.
say "creating SPI/GPIO device-node substitutes for the build (ephemeral /dev)"
for dev in /dev/spidev0.0 /dev/spidev0.1 /dev/gpiochip0; do
  [ -e "$dev" ] || mknod "$dev" c 153 0 2>/dev/null || touch "$dev" 2>/dev/null || true
done

say "lhpc auto-install --yes"
# Exit status is the durable signal: auto-install returns non-zero if a mandatory stack
# failed/blocked (GUI/optional skips are success). Record --status for diagnostics only.
as_op "$LHPC_BIN" auto-install --yes || die "auto-install failed (mandatory stack failed/blocked)"
as_op "$LHPC_BIN" auto-install --status > /var/log/auto-install-status.log 2>&1 || true

# ---- 9. record status / versions / doctor ----------------------------------
say "recording status/versions/doctor"
as_op "$LHPC_BIN" status            > /var/log/lhpc-status.log 2>&1 || true
as_op "$LHPC_BIN" doctor            > /var/log/lhpc-doctor.log 2>&1 || true
# The component/version report is REQUIRED release evidence — fail closed if it can't be produced.
as_op "$LHPC_BIN" status --versions > /var/log/lhpc-versions.log 2>&1 || die "lhpc status --versions failed"
[ -s /var/log/lhpc-versions.log ] || die "component report (status --versions) is empty"

# ---- 10. remove build-time holds; fail closed on a broken dpkg state -------
# The kernel/boot holds were only to survive in-container initramfs generation. Remove them so
# the released device can update those packages (the operator's `apt full-upgrade` must not be
# silently blocked). We keep the base kernel VERSION (we didn't upgrade it here), but unblock it.
if [ -n "${hold_pkgs:-}" ]; then
  # shellcheck disable=SC2086
  apt-mark unhold $hold_pkgs >/dev/null 2>&1 || true
fi
still="$(apt-mark showhold 2>/dev/null | tr '\n' ' ')"
for p in ${hold_pkgs:-}; do
  case " $still " in *" $p "*) die "build-time hold not removed: $p" ;; esac
done
dpkg --configure -a
audit="$(dpkg --audit 2>&1 || true)"; [ -z "$audit" ] || die "dpkg --audit reports unresolved package state: $audit"
say "no holds remain; dpkg audit clean"

# ---- 11. provenance --------------------------------------------------------
mkdir -p /etc /var/lib/lhpc
LHPC_VER="$(as_op "$LHPC_BIN" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo unknown)"
PKG_MANIFEST=/var/lib/lhpc/packages.manifest
dpkg-query -W -f='${Package} ${Version}\n' | sort > "$PKG_MANIFEST"
[ -s "$PKG_MANIFEST" ] || die "package manifest is empty"
PKG_COUNT="$(wc -l < "$PKG_MANIFEST")"
PKG_SHA="$(sha256sum "$PKG_MANIFEST" 2>/dev/null | awk '{print $1}')"
COMP_SHA="$(sha256sum /var/log/lhpc-versions.log 2>/dev/null | awk '{print $1}')"
BUILT_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
  printf '{\n'
  printf '  "variant": "%s",\n' "$VARIANT"
  printf '  "lhpc_commit": "%s",\n' "$INSTALLED_SHA"
  printf '  "lhpc_version": "%s",\n' "$LHPC_VER"
  printf '  "base_url": "%s",\n' "${BASE_URL:-}"
  printf '  "base_sha256": "%s",\n' "${BASE_SHA256:-}"
  printf '  "package_count": %s,\n' "${PKG_COUNT:-0}"
  printf '  "package_manifest_sha256": "%s",\n' "${PKG_SHA:-}"
  printf '  "component_report_sha256": "%s",\n' "${COMP_SHA:-}"
  printf '  "image_build_commit": "%s",\n' "${IMAGE_BUILD_COMMIT:-}"
  printf '  "built_at": "%s",\n' "$BUILT_AT"
  printf '  "workflow_run_id": "%s"\n' "${WORKFLOW_RUN_ID:-}"
  printf '}\n'
} > /etc/lhpc-image.json
# copy the full package manifest + component report where build.sh collects logs (so they reach
# the workflow artifact / release, not only inside the image).
cp "$PKG_MANIFEST" /var/log/lhpc-packages.log 2>/dev/null || true

# ---- 12. done --------------------------------------------------------------
touch /var/lib/lhpc/.provisioned
say "PROVISIONED OK (variant=$VARIANT lhpc=$INSTALLED_SHA pkgs=$PKG_COUNT)"
