#!/usr/bin/env bash
# Resolve the current full SHA of makrohard/loraham-pi-control main at job start, and
# later assert the installed checkout matches (or matches a freshly-resolved main if
# main advanced mid-job). Never resets/moves the checkout to force a match.
#
# Usage:
#   resolve-lhpc.sh resolve                 -> prints the current main full SHA
#   resolve-lhpc.sh assert <installed> <resolved>
#       exit 0 if installed == resolved, OR installed == a freshly-resolved current main;
#       else fail (unexplained mismatch).
# shellcheck shell=bash
set -o errexit -o nounset -o pipefail
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$_here/lib.sh"

REPO="makrohard/loraham-pi-control"
BRANCH="main"

resolve() {
  local sha
  # ls-remote needs no clone and no auth for a public repo.
  sha="$(git ls-remote "https://github.com/$REPO.git" "refs/heads/$BRANCH" | awk '{print $1}')"
  [ "${#sha}" -eq 40 ] || die "could not resolve $REPO $BRANCH SHA (got '$sha')"
  printf '%s\n' "$sha"
}

assert() {
  local installed="$1" resolved="$2" fresh
  [ -n "$installed" ] || die "installed SHA empty — install path did not clone?"
  if [ "$installed" = "$resolved" ]; then
    log "LHPC SHA match: $installed"
    return 0
  fi
  warn "installed ($installed) != job-start resolved ($resolved); checking if main advanced mid-job"
  fresh="$(resolve)"
  if [ "$installed" = "$fresh" ]; then
    log "LHPC main advanced during the job; installed matches current main $fresh"
    return 0
  fi
  die "unexplained LHPC SHA mismatch: installed=$installed job-start=$resolved current-main=$fresh"
}

main() {
  case "${1:-}" in
    resolve) resolve ;;
    assert)  shift; assert "${1:?installed}" "${2:?resolved}" ;;
    *) die "usage: resolve-lhpc.sh resolve | assert <installed> <resolved>" ;;
  esac
}
main "$@"
