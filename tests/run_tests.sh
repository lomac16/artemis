#!/usr/bin/env bash
# Dependency-free tests: build fake filesystem roots and assert on artemis output.
set -uo pipefail
# SC2016: the single-quoted bash -c bodies are intentional; $0/$1 are passed as arguments.
# shellcheck disable=SC2016

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARTEMIS="$HERE/../src/artemis.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASSED=0
FAILED=0

assert() { # description command...
  local desc="$1"
  shift
  if "$@"; then
    PASSED=$((PASSED + 1))
    echo "ok   - $desc"
  else
    FAILED=$((FAILED + 1))
    echo "FAIL - $desc"
  fi
}

make_root() { # dir ssh_root ssh_pass ip_forward passwd_extra
  local d="$1"
  mkdir -p "$d/etc/ssh" "$d/proc/sys/net/ipv4/conf/all"
  printf 'PermitRootLogin %s\nPasswordAuthentication %s\nPermitEmptyPasswords no\n' "$2" "$3" >"$d/etc/ssh/sshd_config"
  printf 'root:x:0:0::/root:/bin/bash\n%s' "$5" >"$d/etc/passwd"
  printf 'root:!:19000::::::\n' >"$d/etc/shadow"
  echo "$4" >"$d/proc/sys/net/ipv4/ip_forward"
  echo 0 >"$d/proc/sys/net/ipv4/conf/all/accept_redirects"
  echo 1 >"$d/proc/sys/net/ipv4/tcp_syncookies"
  chmod 644 "$d/etc/passwd" "$d/etc/ssh/sshd_config"
  chmod 640 "$d/etc/shadow"
}

run() { ARTEMIS_ROOT="$1" bash "$ARTEMIS" "${@:2}"; }

make_root "$TMP/good" no no 0 ''
make_root "$TMP/bad" yes yes 1 $'toor:x:0:0::/root:/bin/bash\n'
chmod 666 "$TMP/bad/etc/passwd"

assert "hardened root exits 0" run "$TMP/good" >/dev/null
assert "weak root exits 1" bash -c '! ARTEMIS_ROOT="$0" bash "$1"' "$TMP/bad" "$ARTEMIS"
assert "detects root SSH login" bash -c 'ARTEMIS_ROOT="$0" bash "$1" | grep -q "SSH-01 *FAIL"' "$TMP/bad" "$ARTEMIS"
assert "detects password SSH login" bash -c 'ARTEMIS_ROOT="$0" bash "$1" | grep -q "SSH-02 *FAIL"' "$TMP/bad" "$ARTEMIS"
assert "detects IP forwarding" bash -c 'ARTEMIS_ROOT="$0" bash "$1" | grep -q "NET-01 *FAIL"' "$TMP/bad" "$ARTEMIS"
assert "detects extra UID 0 account" bash -c 'ARTEMIS_ROOT="$0" bash "$1" | grep -q "ACCT-01 *FAIL.*toor"' "$TMP/bad" "$ARTEMIS"
assert "detects writable /etc/passwd" bash -c 'ARTEMIS_ROOT="$0" bash "$1" | grep -q "FILE-01 *FAIL"' "$TMP/bad" "$ARTEMIS"
assert "good root has no FAIL lines" bash -c '! ARTEMIS_ROOT="$0" bash "$1" | grep -q FAIL' "$TMP/good" "$ARTEMIS"
assert "drop-in overrides sshd_config" bash -c '
  mkdir -p "$0/etc/ssh/sshd_config.d" && echo "PermitRootLogin yes" >"$0/etc/ssh/sshd_config.d/10.conf"
  ARTEMIS_ROOT="$0" bash "$1" | grep -q "SSH-01 *FAIL"' "$TMP/good" "$ARTEMIS"
assert "json output is a valid array" bash -c 'ARTEMIS_ROOT="$0" bash "$1" --json | python3 -c "import sys,json; assert isinstance(json.load(sys.stdin), list)"' "$TMP/bad" "$ARTEMIS"
assert "unknown flag exits 2" bash -c 'bash "$0" --nope 2>/dev/null; [ $? -eq 2 ]' "$ARTEMIS"
assert "missing files are SKIP not FAIL" bash -c 'mkdir -p "$0/empty"; ARTEMIS_ROOT="$0/empty" bash "$1" | grep -q SKIP' "$TMP" "$ARTEMIS"

echo
echo "$PASSED passed, $FAILED failed"
((FAILED == 0))
