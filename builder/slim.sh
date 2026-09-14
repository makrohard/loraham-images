#!/usr/bin/env bash
# loraham-images — Desktop-only, BUILD-ONLY image slimming.
#
# Runs INSIDE the guest (systemd-nspawn), staged by build.sh as /usr/local/sbin/lhpc-slim and
# deleted again by build.sh's disarm step: nothing of this machinery ships. It removes optional
# applications and unused localisation/wallpaper data AFTER every installation step, so the
# released .img.xz fits under the 2 GiB GitHub release cap with room to spare.
#
# Contract — the whole point of this script:
#   * BEFORE anything is removed it NEVER fails the build for a target that moved, vanished or
#     grew a dependant. Every such case is a warning and that group ships UNPRUNED and intact.
#     Upstream drift costs savings, never function.
#   * The boundary is MUTATION, and after it the rule inverts. Once a purge or a deletion has
#     started, a failure can leave the group half-removed, and "ships intact" is then a promise
#     we cannot keep — so that is fail-CLOSED: slim.sh exits non-zero and provision.sh dies.
#     `dpkg --audit` cannot stand in for this. It proves the dpkg database is sane, which it
#     would also be after "A purged, B's removal failed before it started".
#   * It ships nothing persistent: no dpkg path-exclude, no apt pin, no policy on the deployed
#     box. A later `apt full-upgrade` out in the field may legitimately bring some of this back.
#   * A genuinely broken package state is fatal too — provision.sh's `dpkg --audit` runs after.
#
# Usage: slim.sh <variant>          (does nothing unless variant = desktop)
# shellcheck shell=bash
set -o errexit -o nounset -o pipefail

VARIANT="${1:?usage: slim.sh <lite|desktop>}"
LIST="${LHPC_SLIM_LIST:-/usr/local/share/lhpc-slim.list}"
LOG=/var/log/lhpc-slim.log
: > "$LOG"

ts()   { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
human() { numfmt --to=iec "$1" 2>/dev/null || printf '%s B' "$1"; }
say()  { printf '[%s] slim: %s\n' "$(ts)" "$*" | tee -a "$LOG"; }
row()  { printf '%-46s %-9s %s\n' "$1" "$2" "$3" | tee -a "$LOG"; }
WARNINGS=0
# NOT an Actions annotation: this script runs inside the guest, where systemd prefixes every
# console line ("[  454.2] lhpc-provision[390]: ..."). The runner only honours a workflow command
# at the START of a line, so a ::warning:: emitted here is literal text and annotates nothing —
# measured on run 34864391240. build.sh re-emits these on the host, reading them back out of the
# report by this exact "slim WARNING: " marker. Keep the marker and the emitter in step.
warn() {
    WARNINGS=$((WARNINGS + 1))
    printf '[%s] slim WARNING: %s\n' "$(ts)" "$*" | tee -a "$LOG"
}
# Used ONLY past the mutation boundary, where the state is indeterminate and continuing would
# ship an image nobody can describe. provision.sh turns this into a build failure.
fatal() {
    printf '[%s] slim FATAL: %s\n' "$(ts)" "$*" | tee -a "$LOG"
    exit 1
}

# "Freed" is RAW PAYLOAD REMOVED, not allocated blocks reclaimed: path groups sum apparent file
# sizes and package groups sum dpkg's Installed-Size. Both are deterministic and reproducible,
# and neither is the exact ext4 delta — the authoritative number is the final .img.xz size that
# build.sh appends to this report. What it is NOT is a df difference: that reads 0 on a
# filesystem with delayed accounting (overlayfs, measured 2026-09-14) and would silently report a
# working prune as having saved nothing. Raw payload is also NOT compressed bytes — the two
# differ by an order of magnitude for text (see docs/maintenance.md).
TOTAL_FREED=0
credit() { TOTAL_FREED=$((TOTAL_FREED + ${1:-0})); }
# Sum the apparent size of every file under the given paths (0 when none match).
bytes_of() { find "$@" -type f -printf '%s\n' 2>/dev/null | awk '{t+=$1} END{printf "%d", t+0}'; }
# Sum dpkg's Installed-Size (KiB) for a package list.
bytes_of_pkgs() {
    local p t=0 k
    for p in "$@"; do
        k="$(dpkg-query -W -f='${Installed-Size}' "$p" 2>/dev/null || echo 0)"
        t=$((t + ${k:-0}))
    done
    printf '%d' $((t * 1024))
}

if [ "$VARIANT" != "desktop" ]; then
    say "variant=$VARIANT — nothing to do (Lite is far below the cap and is deliberately untouched)"
    exit 0
fi
[ -r "$LIST" ] || { say "no slim list at $LIST — nothing to do"; exit 0; }

say "start (variant=$VARIANT, list=$LIST)"
printf '%-46s %-9s %s\n' "entry" "status" "detail" | tee -a "$LOG"

# ---- 1. package groups -----------------------------------------------------------------------
# Guarded three ways before anything is removed: every member must be installed (an unknown name
# makes `apt-get -s purge` exit 100, which under `set -e` would abort the build — the opposite of
# fail-soft); the simulated removal set must be exactly the group (so a future base that makes one
# of these a dependency of the desktop costs us the saving instead of the desktop); and the
# simulation must install NOTHING. apt documents a simulated run as Conf/Remv/Inst lines, and a
# base that satisfies a dependency by swapping in a replacement would show `Remv wanted` next to
# `Inst replacement` — a removal set that matches while the run quietly adds a package.
while read -r variant action targets; do
    case "$variant" in ''|'#'*) continue ;; esac
    [ "$variant" = "desktop" ] || [ "$variant" = "both" ] || continue
    [ "$action" = "purge" ] || { warn "unknown action '$action' in $LIST — ignored"; continue; }
    group="${targets%%#*}"; group="$(printf '%s' "$group" | xargs)"
    [ -n "$group" ] || continue

    missing=""
    for p in $group; do
        st="$(dpkg-query -W -f='${db:Status-Status}' "$p" 2>/dev/null || true)"
        [ "$st" = "installed" ] || missing="$missing $p"
    done
    if [ -n "$missing" ]; then
        row "purge $group" "STALE" "not installed:$missing — upstream moved or renamed?"
        warn "package group '$group' is stale (not installed:$missing) — nothing purged"
        continue
    fi

    # The `if` context is deliberate: it keeps `set -e` from aborting on a non-zero simulation,
    # and it keeps the exit status, which `sim_out="$(... || true)"` would throw away.
    # shellcheck disable=SC2086   # $group is a deliberate word list
    if sim_out="$(apt-get -s purge $group </dev/null 2>&1)"; then sim_rc=0; else sim_rc=$?; fi
    if [ "$sim_rc" -ne 0 ]; then
        printf '%s\n' "$sim_out" >> "$LOG"
        row "purge $group" "SKIPPED" "simulation failed (rc=$sim_rc) — see $LOG"
        warn "simulating the purge of '$group' failed (rc=$sim_rc) — skipped, group ships intact"
        continue
    fi
    sim="$(printf '%s\n' "$sim_out"  | awk '/^(Purg|Remv) /{print $2}' | sort -u | tr '\n' ' ')"
    inst="$(printf '%s\n' "$sim_out" | awk '/^Inst /{print $2}'        | sort -u | tr '\n' ' ')"
    # shellcheck disable=SC2086   # deliberate word split: one package per line
    want="$(printf '%s\n' $group | sort -u | tr '\n' ' ')"
    if [ "$sim" != "$want" ]; then
        row "purge $group" "SKIPPED" "collateral: ${sim:-<none>}"
        warn "purging '$group' would also remove: ${sim:-<none>} — skipped, group ships intact"
        continue
    fi
    if [ -n "$inst" ]; then
        row "purge $group" "SKIPPED" "would also install: $inst"
        warn "purging '$group' would also INSTALL: $inst — skipped, group ships intact"
        continue
    fi

    # shellcheck disable=SC2086
    freed="$(bytes_of_pkgs $group)"
    # shellcheck disable=SC2086
    if DEBIAN_FRONTEND=noninteractive apt-get -y purge $group </dev/null >>"$LOG" 2>&1; then
        credit "$freed"
        row "purge $group" "applied" "$(human "$freed") freed (raw)"
    else
        # Past the mutation boundary: apt may have purged some members before failing, so the
        # group is neither applied nor intact and no honest status exists for it.
        row "purge $group" "FAILED" "apt-get purge returned non-zero — see $LOG"
        fatal "purging '$group' failed after removal had begun — the image is in an indeterminate state"
    fi
done < "$LIST"

# ---- 2. path groups --------------------------------------------------------------------------
# Each group names its KEEP ANCHORS. If an anchor is missing the base has moved: the group ships
# unpruned. Nothing is ever deleted on a guess.
prune_group() {          # $1 label   $2 anchors (space list)   $3.. deleter (prints bytes freed)
    local label="$1" anchors="$2"; shift 2
    local a missing="" freed
    # shellcheck disable=SC2086   # deliberate word split over the anchor list
    for a in $anchors; do [ -e "$a" ] || missing="$missing $a"; done
    if [ -n "$missing" ]; then
        row "$label" "STALE" "missing anchor:$missing"
        warn "$label: keep-anchor missing ($missing) — group ships unpruned"
        return 0
    fi
    # Same boundary as the purge loop: the deleter removes files, so a non-zero return means an
    # unknown number of them are already gone. There is nothing left to ship intact.
    # NOTE for anyone editing a deleter: `set -e` does NOT apply inside a function whose status is
    # being tested here, so every destructive step in a deleter must propagate its own failure
    # with `|| return 1`. Relying on errexit inside these functions silently reports success.
    freed="$("$@")" || { row "$label" "FAILED" "deletion returned non-zero"
                         fatal "$label: deletion failed after it had begun — the image is in an indeterminate state"; }
    # The keep set is the promise. Re-read the anchors now that the deleter has run: if one of
    # them went with the prune, the group has eaten what it was told to keep, and that is past
    # the mutation boundary. This is the only place that knows pruning actually happened — which
    # is why it does NOT belong in a later gate, where a group that was skipped entirely would
    # be judged by the same rule.
    # shellcheck disable=SC2086   # deliberate word split over the anchor list
    for a in $anchors; do
        [ -e "$a" ] || fatal "$label: pruning removed a keep-anchor it promised to keep: $a"
    done
    credit "$freed"
    row "$label" "applied" "$(human "${freed:-0}") freed (raw)"
}

# 2a. message catalogues — keep de*, en* and the locale.alias FILE that lives among the language
#     directories. This also covers vlc-l10n, whose catalogues are /usr/share/locale/*/LC_MESSAGES.
# shellcheck disable=SC2317   # invoked indirectly by prune_group "$@"
del_locales() {
    local victims freed
    victims="$(find /usr/share/locale -mindepth 1 -maxdepth 1 \
                    ! -name 'de*' ! -name 'en*' ! -name 'locale.alias' -print)"
    [ -n "$victims" ] || { printf '0'; return 0; }
    # Explicit propagation, NOT errexit: this function is called through a `||` status test, where
    # `set -e` is suppressed for everything inside it. Without these a failing rm would fall
    # through to the printf and report success.
    # shellcheck disable=SC2086   # newline-separated paths, none contain spaces
    freed="$(bytes_of $victims)" || return 1
    # shellcheck disable=SC2086
    rm -rf $victims || return 1
    printf '%s' "$freed"
}
prune_group "locales (keep de*, en*)" \
            "/usr/share/locale/de /usr/share/locale/en /usr/share/locale/locale.alias" \
            del_locales

# 2b. Chromium's UI translations — keep German and English.
# shellcheck disable=SC2317   # invoked indirectly by prune_group "$@"
del_chromium_locales() {
    local victims freed
    victims="$(find /usr/lib/chromium/locales -mindepth 1 -maxdepth 1 -name '*.pak' \
                    ! -name 'de.pak' ! -name 'en-US.pak' -print)"
    [ -n "$victims" ] || { printf '0'; return 0; }
    # Explicit propagation, same reason as del_locales.
    # shellcheck disable=SC2086
    freed="$(bytes_of $victims)" || return 1
    # shellcheck disable=SC2086
    rm -f $victims || return 1
    printf '%s' "$freed"
}
prune_group "chromium UI translations (keep de, en-US)" \
            "/usr/lib/chromium/locales/de.pak /usr/lib/chromium/locales/en-US.pak" \
            del_chromium_locales

# 2c. Wallpapers — the keep set is READ FROM /etc, never assumed. Existence of the four known
#     files is not enough: a base that adds a wallpaper AND points the greeter at it would pass an
#     existence check and then have its live background deleted. If anything referenced falls
#     outside the keep set, the whole group is stale.
WP_DIR=/usr/share/rpd-wallpaper
WP_KEEP="fjord.jpg sunrise.jpg RPiSystem.png RPiSystem_dark.png"
# shellcheck disable=SC2317   # called below once the directory check passes
wallpapers() {
    local referenced ref outside=""
    referenced="$(grep -rhsoE "$WP_DIR/[A-Za-z0-9_.-]+\.(jpg|jpeg|png)" /etc 2>/dev/null \
                  | sed "s|$WP_DIR/||" | sort -u)"
    if [ -z "$referenced" ]; then
        row "wallpapers (keep referenced)" "STALE" "no /etc reference found — layout changed?"
        warn "wallpapers: no /etc reference to $WP_DIR found — group ships unpruned"
        return 0
    fi
    for ref in $referenced; do
        case " $WP_KEEP " in *" $ref "*) ;; *) outside="$outside $ref" ;; esac
    done
    if [ -n "$outside" ]; then
        row "wallpapers (keep referenced)" "STALE" "referenced outside keep set:$outside"
        warn "wallpapers: /etc references$outside, which is outside the keep set — group ships unpruned"
        return 0
    fi
    local victims freed keep_expr=()
    for ref in $WP_KEEP; do keep_expr+=( ! -name "$ref" ); done
    victims="$(find "$WP_DIR" -mindepth 1 -maxdepth 1 -type f "${keep_expr[@]}" -print)"
    if [ -z "$victims" ]; then
        row "wallpapers (keep referenced)" "applied" "0 freed (raw) — nothing to remove"
        return 0
    fi
    # shellcheck disable=SC2086
    freed="$(bytes_of $victims)"
    # shellcheck disable=SC2086
    rm -f $victims || fatal "wallpapers: deletion failed after it had begun — the image is in an indeterminate state"
    # Same promise as prune_group's post-prune re-read: what /etc points at must have survived.
    for ref in $referenced; do
        [ -f "$WP_DIR/$ref" ] || fatal "wallpapers: pruning removed a referenced wallpaper: $ref"
    done
    credit "$freed"
    row "wallpapers (keep referenced)" "applied" "$(human "$freed") freed (raw)"
}
if [ -d "$WP_DIR" ]; then
    wallpapers
else
    row "wallpapers (keep referenced)" "STALE" "$WP_DIR absent"
    warn "wallpapers: $WP_DIR does not exist — group ships unpruned"
fi

# ---- 3. summary ------------------------------------------------------------------------------
say "TOTAL freed $(human "$TOTAL_FREED") of raw filesystem ($WARNINGS warning(s))"
say "raw bytes freed are NOT compressed bytes saved — build.sh appends the real .img.xz size below"
exit 0
