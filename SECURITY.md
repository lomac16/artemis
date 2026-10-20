# Security Policy

## Scope

Artemis is a **read-only** auditor. It reads system files and reports; it never
modifies the system. A bug that makes it write, delete, or send data anywhere
is a security issue.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting: **Security > Report a
vulnerability** on this repository. Do not open a public issue for security
problems.

You can expect an acknowledgement within 7 days.

## Handling secrets

This repo must never contain credentials, keys, or real hostnames and IPs. CI
and a pre-commit hook run gitleaks. If you find a secret in the history, report
it privately and rotate it; deleting the file is not enough.
