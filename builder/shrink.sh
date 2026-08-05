#!/usr/bin/env bash
# loraham-images — shrink the sealed raw image to the smallest safe publishable size.
# Mirror of the build-time growth. Never zerofree a mounted fs. Operates on the raw image
# with NOTHING mounted.
#
# Usage: shrink.sh <raw_image>
# shellcheck shell=bash
set -o errexit -o nounset -o pipefail
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$_here/lib.sh"

IMG="${1:?raw image}"
MARGIN_MB=64          # documented safety margin added past the minimal filesystem
trap cleanup_image EXIT INT TERM

group_begin "shrink: minimise partition 2 + truncate image"
attach_loop "$IMG"
P2="${LOOPDEV}p2"

fsck_checked "$P2"

# zerofree the (unmounted) fs to make the tail compress well, then minimise.
command -v zerofree >/dev/null 2>&1 && zerofree "$P2" || warn "zerofree unavailable — skipping"

resize2fs -M "$P2"
# read resulting geometry
blk_count="$(dumpe2fs -h "$P2" 2>/dev/null | awk -F: '/Block count/{gsub(/ /,"",$2);print $2}')"
blk_size="$(dumpe2fs -h "$P2" 2>/dev/null | awk -F: '/Block size/{gsub(/ /,"",$2);print $2}')"
[ -n "$blk_count" ] && [ -n "$blk_size" ] || die "could not read fs geometry"
fs_bytes=$(( blk_count * blk_size ))
log "minimised fs: ${blk_count} x ${blk_size} = ${fs_bytes} bytes"

# partition-2 start (sectors), sector size
p2_start="$(partx -g -o START -s "$IMG" | sed -n '2p' | tr -d ' ')"
sec=512
# new size in sectors = fs bytes + margin, then align up to 4 MiB
new_bytes=$(( fs_bytes + MARGIN_MB*1024*1024 ))
align=$(( 4*1024*1024 ))
new_bytes=$(( (new_bytes + align - 1) / align * align ))
new_size_sectors=$(( new_bytes / sec ))
new_end_sector=$(( p2_start + new_size_sectors - 1 ))
log "resizing partition 2 to ${new_size_sectors} sectors (start=${p2_start}, end=${new_end_sector}, size=${new_bytes} bytes)"

# detach before repartitioning to avoid stale kernel geometry
detach_image

# parted refuses a destructive shrink in --script mode; sfdisk -N resizes non-interactively,
# keeping the partition's start, type and attributes (only the size field changes).
printf '%s,%s\n' "$p2_start" "$new_size_sectors" | sfdisk --no-reread -f -N 2 "$IMG"

# re-attach, re-read, fsck again
attach_loop "$IMG"
fsck_checked "${LOOPDEV}p2"
# revalidate fs type
blkid_type="$(blkid -o value -s TYPE "${LOOPDEV}p2" || true)"
[ "$blkid_type" = "ext4" ] || die "p2 fs type is '$blkid_type', expected ext4 after shrink"
boot_type="$(blkid -o value -s TYPE "${LOOPDEV}p1" || true)"
case "$boot_type" in vfat|msdos) : ;; *) die "p1 fs type is '$boot_type', expected vfat" ;; esac
detach_image

# truncate the raw image just past the new partition end
final_sectors=$(( new_end_sector + 1 ))
truncate -s $(( final_sectors * sec )) "$IMG"
log "truncated image to $(( final_sectors * sec )) bytes"
group_end
log "SHRINK OK: $IMG"
