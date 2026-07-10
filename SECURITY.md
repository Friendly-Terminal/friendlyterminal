# Security Policy

FriendlyTerminal executes real shell commands and handles local file paths, so
security reports are taken seriously.

## Supported versions

Security fixes are applied to the latest release and the current `main` branch.
Older releases may not receive backports.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting feature on this repository. Do not
open a public issue for a vulnerability that could expose users, files, tokens,
shell input, or command output.

Include the affected platform and version, impact, reproduction steps, and a
minimal proof of concept. Remove real credentials and personal information.
Please allow maintainers a reasonable opportunity to investigate and release a
fix before public disclosure.

## Security boundaries

- FriendlyTerminal runs commands only when the user enters or selects them.
- The Linux renderer has no direct Node.js or filesystem access; privileged
  operations cross a validated IPC boundary.
- External links are restricted to HTTP and HTTPS.
- Shell integration is local and does not transmit command data.
- Optional macOS AI uses Apple's on-device Foundation Models.

No terminal can make arbitrary commands intrinsically safe. Review commands
before running them and never paste secrets into an untrusted prompt.
