#!/usr/bin/env bash
# Resolve the current full SHA of makrohard/loraham-pi-control main at job start (build.sh calls
# this once). The installed-vs-resolved MATCH is asserted INLINE in provision.sh — not here —
# because provision runs in the container where this host script is never staged (note is there).
#
# Usage: resolve-lhpc.sh resolve   -> prints the current main full SHA
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

main() {
  case "${1:-}" in
    resolve) resolve ;;
    *) die "usage: resolve-lhpc.sh resolve" ;;
  esac
}
main "$@"
