#!/usr/bin/env bash
# Prove the STRICT phase-boundary detach stops the build instead of walking into a destructive
# operation on a still-mounted image.
#
# Every detach_image() call site is immediately followed by something that rewrites the same
# backing file — shrink.sh does `sfdisk -N 2` on the partition table and then `truncate`; gate-a2
# fsck/resize2fs's the copy and boots it. The previous helper ran under `set +e`, ignored a failed
# umount or `losetup -d`, and cleared MNT_*/LOOPDEV anyway, so a busy unmount let the next
# attach_loop open a SECOND loop device over a filesystem that was still mounted through the
# first. That corrupts by timing and surfaces as a bad published image, not as a red build.
#
# The real function is extracted from lib.sh (not a copy) and driven with injected failures.
# shellcheck disable=SC2317,SC2034
set -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

fn="$(mktemp)"; trap 'rm -f "$fn"' EXIT
awk '/^detach_image\(\)/{p=1} p{print} /^}/{if(p) exit}' builder/lib.sh > "$fn"
grep -q 'detach_image' "$fn" || { echo "could not extract detach_image"; exit 1; }

fails=0
expect(){ case "$3" in *"$2"*) echo "  ok: $1";; *) echo "  FAIL: $1 — want '$2' in '$3'"; fails=1;; esac; }

# $1 = scenario: which operation refuses. Emits "DIED: <reason>" or "REACHED-DESTRUCTIVE".
run(){
  (
    scenario="$1"
    die(){ echo "DIED: $*"; exit 9; }
    sync(){ :; }
    sleep(){ :; }   # the wait itself is real; only the test's patience is faked
    _probes=0
    MNT_BOOT=/mnt/boot; MNT_ROOT=/mnt/root; LOOPDEV=/dev/loop9
    mountpoint(){ # -q <path>
      case "$scenario:$2" in
        umount-refused:/mnt/root) return 0 ;;   # still mounted after umount "succeeded"
        *) [ "${_first_call:-1}" = 1 ] && return 0 || return 1 ;;
      esac
    }
    umount(){ [ "$scenario" = "umount-fails" ] && return 1; _first_call=0; return 0; }
    losetup(){
      case "$1" in
        -d) [ "$scenario" = "losetup-fails" ] && return 1; return 0 ;;
        *)  case "$scenario" in
              loop-still-attached) return 0 ;;                       # never clears: genuinely busy
              loop-clears-late)                                      # clears after a few probes
                _probes=$((_probes + 1)); [ "$_probes" -le 3 ] && return 0; return 1 ;;
              *) return 1 ;;
            esac ;;
      esac
    }
    # shellcheck source=/dev/null
    . "$fn"
    detach_image || exit $?
    echo "REACHED-DESTRUCTIVE"
  ) 2>&1
}

echo "== strict detach: injected failures must stop before sfdisk/truncate =="
expect "failed umount stops the build"        "DIED: detach: umount failed"            "$(run umount-fails)"
expect "still-mounted path stops the build"   "DIED: detach: /mnt/root still a mountpoint" "$(run umount-refused)"
expect "failed losetup -d stops the build"    "DIED: detach: losetup -d failed"        "$(run losetup-fails)"
expect "surviving loop device stops the build" "DIED: detach: /dev/loop9 still attached" "$(run loop-still-attached)"
expect "clean detach proceeds"                "REACHED-DESTRUCTIVE"                    "$(run clean)"
# `losetup -d` is asynchronous, so a device that is still listed for a moment is NORMAL, not busy.
# Failing on that first probe is what broke the v0.1.6 lite build one second after a resize2fs.
expect "a briefly-lingering device is waited out, not fatal" \
       "REACHED-DESTRUCTIVE" "$(run loop-clears-late)"

[ "$fails" -eq 0 ] && echo "DETACH TESTS PASSED" || { echo "DETACH TESTS FAILED"; exit 1; }
