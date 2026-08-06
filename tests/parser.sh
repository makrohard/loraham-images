#!/usr/bin/env bash
# Exercise the REAL lhpc-config.txt parser (extracted from lhpc-firstboot) with valid input,
# misspelled keys and invalid values. Guards the primary onboarding failure mode: a typo'd key
# silently leaving the box on the public defaults.
# stubs (say/cfg_reject/fail) and BOOTCFG are used by parse_bootcfg, sourced dynamically below,
# so shellcheck cannot see the uses.
# shellcheck disable=SC2317,SC2034
set -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
FB=overlay/usr/local/sbin/lhpc-firstboot
fn="$(mktemp)"; trap 'rm -f "$fn"' EXIT
# extract the parse_bootcfg() function body (up to its closing brace at column 0)
awk '/^parse_bootcfg\(\)/{p=1} p{print} /^}/{if(p) exit}' "$FB" > "$fn"
grep -q 'parse_bootcfg' "$fn" || { echo "could not extract parse_bootcfg"; exit 1; }

run(){ # $1 = config-file text -> echoes "REJECT: <reason>" or a sorted CFG dump
  local cf; cf="$(mktemp)"; printf '%s\n' "$1" > "$cf"
  (
    set +e
    say(){ :; }
    cfg_reject(){ echo "REJECT: $1"; exit 7; }
    fail(){ echo "REJECT: $*"; exit 7; }
    declare -A CFG=()
    BOOTCFG="$cf"
    # shellcheck source=/dev/null
    . "$fn"
    parse_bootcfg
    { for k in "${!CFG[@]}"; do echo "$k=${CFG[$k]}"; done; } | sort | tr '\n' ';'; echo
  )
  rm -f "$cf"
}

fails=0
expect(){ case "$3" in *"$2"*) echo "  ok: $1";; *) echo "  FAIL: $1 — want '$2' in '$3'"; fails=1;; esac; }

expect "valid config accepted"       "AP_PSK=abcdefgh" "$(run $'HOSTNAME=lab\nPASSWORD=secret1\nAP_PSK=abcdefgh\nWIFI_COUNTRY=de\nCALL=N0CALL')"
expect "country upper-cased"         "WIFI_COUNTRY=DE" "$(run 'WIFI_COUNTRY=de')"
expect "inline comment stripped"     "AP_PSK=abcdefgh;" "$(run 'AP_PSK=abcdefgh   # note')"
expect "misspelled key rejected"     "REJECT: unknown key 'PASSWROD'" "$(run 'PASSWROD=secret')"
expect "bad country rejected"        "REJECT: WIFI_COUNTRY must be two letters" "$(run 'WIFI_COUNTRY=Germany')"
expect "redacted password rejected"   "REJECT: PASSWORD=REDACTED is the placeholder" "$(run 'PASSWORD=REDACTED')"
expect "redacted AP key rejected"     "REJECT: AP_PSK=REDACTED is the placeholder"   "$(run 'AP_PSK=REDACTED')"
expect "timezone accepted"           "TIMEZONE=Europe/Berlin" "$(run 'TIMEZONE=Europe/Berlin')"
expect "unknown timezone rejected"   "REJECT: TIMEZONE 'Europe/Atlantis' is not a known zone" "$(run 'TIMEZONE=Europe/Atlantis')"
expect "timezone traversal rejected" "REJECT: TIMEZONE must be a zone name" "$(run 'TIMEZONE=../../etc/shadow')"
expect "absolute timezone rejected"  "REJECT: TIMEZONE must be a zone name" "$(run 'TIMEZONE=/usr/share/zoneinfo/Europe/Berlin')"
expect "short PSK rejected"          "REJECT: AP_PSK must be 8" "$(run 'AP_PSK=short')"
expect "bad hostname rejected"       "REJECT: HOSTNAME may contain" "$(run 'HOSTNAME=bad host')"
expect "malformed line rejected"     "REJECT: malformed line" "$(run 'this is not valid')"

[ "$fails" -eq 0 ] && echo "PARSER TESTS PASSED" || { echo "PARSER TESTS FAILED"; exit 1; }
