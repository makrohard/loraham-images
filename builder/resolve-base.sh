#!/usr/bin/env bash
# Resolve the LATEST official Raspberry Pi OS image for a stream, verify its official
# sha256, and (after download) verify codename=trixie + arch=arm64 + expected layout.
#
# Usage: resolve-base.sh <stream>          -> prints "<url> <sha256>" for the newest build
#        resolve-base.sh --verify-mounted <root>   -> asserts codename/arch on a mounted root
#
# "Latest" = the newest raspios_*_arm64-YYYY-MM-DD directory that actually contains an
# .img.xz for the trixie release. We never silently cross to a later Debian codename:
# the mounted-root check fails the build if VERSION_CODENAME != trixie.
# shellcheck shell=bash
set -o errexit -o nounset -o pipefail
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$_here/lib.sh"

BASE_HOST="https://downloads.raspberrypi.com"

resolve_stream() {
  local stream="$1" idx dirs dir dirlist img="" sha url
  idx="$(curl -fsSL --max-time 60 "$BASE_HOST/$stream/images/")" \
    || die "cannot list $stream image directory"
  dirs="$(printf '%s\n' "$idx" | grep -oE "${stream}-[0-9]{4}-[0-9]{2}-[0-9]{2}" | sort -u | sort -r)"
  [ -n "$dirs" ] || die "no dated build directory found for $stream"
  # newest dir first, but take the newest one that actually holds a TRIXIE arm64 image — so a
  # future dir carrying a later Debian codename is skipped rather than failing the resolve.
  for dir in $dirs; do
    # A load FAILURE (network/HTTP) must not silently skip to an older image — retry, then die.
    if ! dirlist="$(curl -fsSL --retry 3 --retry-delay 2 --max-time 90 "$BASE_HOST/$stream/images/$dir/")"; then
      die "failed to load $stream/$dir after retries (network/HTTP) — refusing to fall back to an older image"
    fi
    img="$(printf '%s\n' "$dirlist" \
          | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}-raspios-trixie-arm64[a-z-]*\.img\.xz' \
          | sort -u | head -1)"
    [ -n "$img" ] && break   # this dir holds a Trixie image
    # else: dir loaded OK but has no Trixie image (a newer codename) — try the next (older) dir
  done
  [ -n "$img" ] || die "no trixie arm64 .img.xz in any dated dir of $stream (codename moved past trixie?)"
  url="$BASE_HOST/$stream/images/$dir/$img"
  sha="$(curl -fsSL --max-time 60 "$url.sha256" | awk '{print $1}')" \
    || die "cannot fetch sha256 for $img"
  [ "${#sha}" -eq 64 ] || die "bad sha256 for $img: '$sha'"
  printf '%s %s\n' "$url" "$sha"
}

verify_mounted() {
  local root="$1" codename arch
  codename="$(sed -n 's/^VERSION_CODENAME=//p' "$root/etc/os-release" 2>/dev/null | tr -d '"')"
  [ "$codename" = "trixie" ] || die "base VERSION_CODENAME='$codename', expected trixie (refusing codename cross)"
  arch="$(chroot "$root" dpkg --print-architecture 2>/dev/null || true)"
  [ "$arch" = "arm64" ] || die "base dpkg arch='$arch', expected arm64"
  [ -f "$root/boot/firmware/cmdline.txt" ] || die "expected boot layout missing: /boot/firmware/cmdline.txt"
  log "base verified: trixie / arm64 / expected layout"
}

main() {
  case "${1:-}" in
    --verify-mounted) shift; verify_mounted "${1:?root required}" ;;
    '' ) die "usage: resolve-base.sh <stream> | --verify-mounted <root>" ;;
    * )  resolve_stream "$1" ;;
  esac
}
main "$@"
