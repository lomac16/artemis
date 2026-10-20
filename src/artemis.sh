#!/usr/bin/env bash
# artemis: read-only Linux hardening auditor.
# Reports PASS / FAIL / SKIP per check. It never changes the system.
#
# Usage: artemis.sh [--json] [--help]
# Env:   ARTEMIS_ROOT  filesystem root to audit (default /). Used by the tests.
set -uo pipefail

ROOT="${ARTEMIS_ROOT:-}"
ROOT="${ROOT%/}"
FORMAT=text
RESULTS=()
FAILS=0

usage() {
  sed -n '2,6p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

record() { # id status description detail
  RESULTS+=("$1|$2|$3|$4")
  [[ "$2" == FAIL ]] && FAILS=$((FAILS + 1))
  return 0
}

# Effective sshd value: drop-ins are read before sshd_config, first match wins.
sshd_value() {
  local key="$1" files=() f
  for f in "$ROOT"/etc/ssh/sshd_config.d/*.conf "$ROOT"/etc/ssh/sshd_config; do
    [[ -r "$f" ]] && files+=("$f")
  done
  [[ ${#files[@]} -eq 0 ]] && return 1
  awk -v k="$key" 'tolower($1) == tolower(k) { print tolower($2); exit }' "${files[@]}"
}

check_sshd() { # id key wanted description
  local id="$1" key="$2" want="$3" desc="$4" got
  if [[ ! -r "$ROOT/etc/ssh/sshd_config" ]]; then
    record "$id" SKIP "$desc" "sshd_config not found"
    return
  fi
  got="$(sshd_value "$key")"
  if [[ -z "$got" ]]; then
    record "$id" FAIL "$desc" "$key not set explicitly (want $want)"
  elif [[ "$got" == "$want" ]]; then
    record "$id" PASS "$desc" "$key $got"
  else
    record "$id" FAIL "$desc" "$key is $got (want $want)"
  fi
}

check_mode() { # id path max_octal_mode description
  local id="$1" path="$ROOT$2" max="$3" desc="$4" mode
  if [[ ! -e "$path" ]]; then
    record "$id" SKIP "$desc" "$2 not found"
    return
  fi
  mode="$(stat -c %a "$path")"
  # Fail if the file grants any permission bit the limit does not.
  if (((8#$mode & ~8#$max) == 0)); then
    record "$id" PASS "$desc" "$2 mode $mode"
  else
    record "$id" FAIL "$desc" "$2 mode $mode (max $max)"
  fi
}

check_sysctl() { # id sysctl.name wanted description
  local id="$1" name="$2" want="$3" desc="$4" file got
  file="$ROOT/proc/sys/$(tr . / <<<"$name")"
  if [[ ! -r "$file" ]]; then
    record "$id" SKIP "$desc" "$name unavailable"
    return
  fi
  got="$(<"$file")"
  if [[ "$got" == "$want" ]]; then
    record "$id" PASS "$desc" "$name = $got"
  else
    record "$id" FAIL "$desc" "$name = $got (want $want)"
  fi
}

check_accounts() {
  local passwd="$ROOT/etc/passwd" shadow="$ROOT/etc/shadow" extra empty
  if [[ -r "$passwd" ]]; then
    extra="$(awk -F: '$3 == 0 && $1 != "root" { printf "%s ", $1 }' "$passwd")"
    if [[ -z "$extra" ]]; then
      record ACCT-01 PASS "Only root has UID 0" "no extra UID 0 accounts"
    else
      record ACCT-01 FAIL "Only root has UID 0" "extra UID 0: ${extra% }"
    fi
  else
    record ACCT-01 SKIP "Only root has UID 0" "/etc/passwd not readable"
  fi
  if [[ -r "$shadow" ]]; then
    empty="$(awk -F: '$2 == "" { printf "%s ", $1 }' "$shadow")"
    if [[ -z "$empty" ]]; then
      record ACCT-02 PASS "No empty passwords" "none found"
    else
      record ACCT-02 FAIL "No empty passwords" "empty password: ${empty% }"
    fi
  else
    record ACCT-02 SKIP "No empty passwords" "/etc/shadow not readable (run as root)"
  fi
}

run_checks() {
  check_sshd SSH-01 PermitRootLogin no "SSH root login disabled"
  check_sshd SSH-02 PasswordAuthentication no "SSH password login disabled"
  check_sshd SSH-03 PermitEmptyPasswords no "SSH empty passwords refused"
  check_mode FILE-01 /etc/passwd 644 "/etc/passwd not group/world writable"
  check_mode FILE-02 /etc/shadow 640 "/etc/shadow not world readable"
  check_mode FILE-03 /etc/ssh/sshd_config 644 "sshd_config not group/world writable"
  check_sysctl NET-01 net.ipv4.ip_forward 0 "IP forwarding disabled"
  check_sysctl NET-02 net.ipv4.conf.all.accept_redirects 0 "ICMP redirects ignored"
  check_sysctl NET-03 net.ipv4.tcp_syncookies 1 "SYN cookies enabled"
  check_accounts
}

json_escape() { local s="${1//\\/\\\\}"; printf '%s' "${s//\"/\\\"}"; }

report() {
  local r id status desc detail first=1
  if [[ "$FORMAT" == json ]]; then
    printf '['
    for r in "${RESULTS[@]}"; do
      IFS='|' read -r id status desc detail <<<"$r"
      ((first)) || printf ','
      first=0
      printf '{"id":"%s","status":"%s","description":"%s","detail":"%s"}' \
        "$id" "$status" "$(json_escape "$desc")" "$(json_escape "$detail")"
    done
    printf ']\n'
  else
    for r in "${RESULTS[@]}"; do
      IFS='|' read -r id status desc detail <<<"$r"
      printf '%-8s %-5s %s (%s)\n' "$id" "$status" "$desc" "$detail"
    done
    printf '\n%d checks, %d failed\n' "${#RESULTS[@]}" "$FAILS"
  fi
}

main() {
  case "${1:-}" in
    --json) FORMAT=json ;;
    -h | --help) usage; exit 0 ;;
    "") ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  run_checks
  report
  ((FAILS == 0))
}

main "$@"
