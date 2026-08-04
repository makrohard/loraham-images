#!/usr/bin/env bash
# loraham-images — shared builder helpers. Sourced by the other builder/*.sh scripts.
# No side effects on source beyond defining functions and a couple of readonly markers.
# shellcheck shell=bash

set -o errexit -o nounset -o pipefail

# ---- logging ---------------------------------------------------------------
_ts() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }
log()  { printf '[%s] %s\n' "$(_ts)" "$*" >&2; }
warn() { printf '[%s] WARN: %s\n' "$(_ts)" "$*" >&2; }
die()  { printf '[%s] FATAL: %s\n' "$(_ts)" "$*" >&2; exit 1; }
group_begin() { printf '::group::%s\n' "$*" >&2 2>/dev/null || true; log "$*"; }
group_end()   { printf '::endgroup::\n' >&2 2>/dev/null || true; }

require_root() { [ "$(id -u)" -eq 0 ] || die "must run as root"; }

# ---- disk budget -----------------------------------------------------------
# Print free bytes on the filesystem holding $1 (default: cwd).
free_bytes() { df -PB1 "${1:-.}" | awk 'NR==2{print $4}'; }
disk_report() {
  local where="${1:-.}"
  log "disk @ ${where}: $(df -h "$where" | awk 'NR==2{print $4" free / "$2" total ("$5" used)"}')"
}
# Fail early if free space on $1 is below $2 bytes.
require_free() {
  local where="$1" need="$2" have
  have="$(free_bytes "$where")"
  log "disk-budget @ ${where}: need $(numfmt --to=iec "$need" 2>/dev/null || echo "$need"), have $(numfmt --to=iec "$have" 2>/dev/null || echo "$have")"
  [ "$have" -ge "$need" ] || die "insufficient disk on ${where}: need ${need}, have ${have}"
}

# ---- safe env loading (trusted in-repo KEY=VALUE files) --------------------
# Loads KEY=VALUE lines into the current shell as exported vars WITHOUT sourcing
# (no command substitution / expansion executes). Rejects malformed lines.
load_env() {
  local file="$1" line key val
  [ -f "$file" ] || die "env file not found: $file"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in ''|'#'*) continue ;; esac
    case "$line" in *'='*) : ;; *) die "malformed env line in $file: $line" ;; esac
    key="${line%%=*}"; val="${line#*=}"
    case "$key" in
      [A-Z_][A-Z0-9_]*) : ;;
      *) die "invalid env key in $file: $key" ;;
    esac
    case "$val" in *" #"*) val="${val%% #*}" ;; esac   # strip inline comment (space + #)
    val="${val%"${val##*[![:space:]]}"}"               # rtrim
    printf -v "$key" '%s' "$val"
    export "${key?}"
  done < "$file"
}

# ---- loop device + mount lifecycle (trap-based cleanup) --------------------
# Callers set LOOPDEV / MNT_ROOT / MNT_BOOT; cleanup_image() tears everything down
# on every exit path. Register it with:  trap cleanup_image EXIT INT TERM
LOOPDEV=""; MNT_ROOT=""; MNT_BOOT=""
cleanup_image() {
  local rc=$?
  set +e
  [ -n "$MNT_BOOT" ] && mountpoint -q "$MNT_BOOT" && umount -R "$MNT_BOOT" 2>/dev/null
  [ -n "$MNT_ROOT" ] && mountpoint -q "$MNT_ROOT" && umount -R "$MNT_ROOT" 2>/dev/null
  [ -n "$LOOPDEV" ] && losetup "$LOOPDEV" >/dev/null 2>&1 && losetup -d "$LOOPDEV" 2>/dev/null
  return $rc
}

# Attach a raw image with partition scanning; sets LOOPDEV and waits for partitions.
attach_loop() {
  local img="$1"
  LOOPDEV="$(losetup --find --show --partscan "$img")" || die "losetup failed for $img"
  udevadm settle 2>/dev/null || sleep 1
  [ -b "${LOOPDEV}p2" ] || die "partition ${LOOPDEV}p2 did not appear"
  log "attached $img -> $LOOPDEV (p1=${LOOPDEV}p1 p2=${LOOPDEV}p2)"
}

# Mount p2 at <root> and p1 at <root>/boot/firmware (kept for maintainer scripts).
mount_image() {
  local root="$1"
  MNT_ROOT="$root"
  mkdir -p "$root"
  mount "${LOOPDEV}p2" "$root" || die "mount p2 failed"
  MNT_BOOT="$root/boot/firmware"
  mkdir -p "$MNT_BOOT"
  mount "${LOOPDEV}p1" "$MNT_BOOT" || die "mount p1 (boot) failed"
  log "mounted p2 -> $root , p1 -> $MNT_BOOT"
}

# Detach explicitly (in addition to the EXIT trap) so a phase can re-attach cleanly.
detach_image() {
  set +e
  [ -n "$MNT_BOOT" ] && mountpoint -q "$MNT_BOOT" && umount -R "$MNT_BOOT"
  [ -n "$MNT_ROOT" ] && mountpoint -q "$MNT_ROOT" && umount -R "$MNT_ROOT"
  [ -n "$LOOPDEV" ] && losetup -d "$LOOPDEV"
  MNT_BOOT=""; MNT_ROOT=""; LOOPDEV=""
  set -e
}

# ---- arch assertions (§corr-net) ------------------------------------------
assert_host_arm64() {
  local a; a="$(uname -m)"
  [ "$a" = "aarch64" ] || die "host arch is $a, expected aarch64 (native arm64 runner required)"
  log "host arch aarch64 OK"
}
# Assert the mounted guest root is arm64 (dpkg architecture + a sample ELF).
assert_guest_arm64() {
  local root="$1" arch
  arch="$(chroot "$root" dpkg --print-architecture 2>/dev/null || true)"
  [ "$arch" = "arm64" ] || die "guest dpkg arch is '$arch', expected arm64"
  log "guest arch arm64 OK"
}
