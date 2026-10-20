# Artemis

A small, **read-only** Linux hardening auditor written in Bash, with tests and CI.
It checks SSH, file permissions, kernel network settings and accounts, then
reports PASS / FAIL / SKIP. It never changes your system.

## Usage

```bash
bash src/artemis.sh          # human-readable report
bash src/artemis.sh --json   # machine-readable report
sudo bash src/artemis.sh     # also checks /etc/shadow
```

Exit code is `0` when nothing failed, `1` when at least one check failed.

## Example

```
SSH-01   FAIL  SSH root login disabled (PermitRootLogin is yes (want no))
FILE-02  PASS  /etc/shadow not world readable (/etc/shadow mode 640)

11 checks, 5 failed
```

## Tests

```bash
bash tests/run_tests.sh
```

Tests build fake filesystem roots in a temp directory (`ARTEMIS_ROOT`), so they
never touch the real system and need no dependencies.

## What each check means

See [docs/CHECKLIST.md](docs/CHECKLIST.md).

## Design choices

- **Read-only by design.** Auditing is safe to run anywhere; fixing is a human decision.
- **Testable.** `ARTEMIS_ROOT` points the script at a fixture tree.
- **Secrets-safe.** gitleaks and ShellCheck run in pre-commit and CI; CI has
  read-only permissions and a checksum-verified scanner download.

## Roadmap

- [ ] More checks: auditd, unattended upgrades, firewall state, world-writable files
- [ ] CIS benchmark ID mapping
- [ ] HTML report

## What I learned

_CI stands for continuous integration._

## License

MIT, see [LICENSE](LICENSE). Security issues: see [SECURITY.md](SECURITY.md).
