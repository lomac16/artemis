# Check catalogue

Each check maps to a common hardening benchmark idea (CIS-style). Artemis only
reports; remediation is manual.

| ID | What it checks | Why it matters | Fix |
|----|----------------|----------------|-----|
| SSH-01 | `PermitRootLogin no` | Stops direct brute-forcing of the root account | Set in `/etc/ssh/sshd_config`, reload sshd |
| SSH-02 | `PasswordAuthentication no` | Forces key-based login | Set after confirming your key works |
| SSH-03 | `PermitEmptyPasswords no` | Blocks accounts with no password | Set in sshd_config |
| FILE-01 | `/etc/passwd` mode <= 644 | Writable passwd means account takeover | `chmod 644 /etc/passwd` |
| FILE-02 | `/etc/shadow` mode <= 640 | Password hashes must not be world readable | `chmod 640 /etc/shadow` |
| FILE-03 | `sshd_config` mode <= 644 | Prevents tampering with SSH policy | `chmod 644 /etc/ssh/sshd_config` |
| NET-01 | `ip_forward = 0` | A non-router should not forward packets | `sysctl -w net.ipv4.ip_forward=0` |
| NET-02 | `accept_redirects = 0` | Prevents route hijacking via ICMP | sysctl |
| NET-03 | `tcp_syncookies = 1` | Mitigates SYN flood attacks | sysctl |
| ACCT-01 | Only root has UID 0 | A second UID 0 account is a backdoor | Investigate and remove |
| ACCT-02 | No empty password fields | Anyone can log in as that user | `passwd -l user` |

## Known limits

- sshd resolution is simplified: drop-ins in `sshd_config.d` are read first,
  then `sshd_config`, first match wins. `Match` blocks and `Include` order are
  not fully evaluated.
- `ACCT-02` needs root to read `/etc/shadow`; otherwise it reports SKIP.
