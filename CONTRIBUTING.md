# Contributing to FriendlyTerminal

Thanks for helping make the terminal more approachable. Bug reports, focused
feature proposals, documentation fixes, tests, and platform improvements are all
welcome.

## Before you start

- Search existing issues and pull requests before opening a duplicate.
- Open an issue before a large architectural change so maintainers and
  contributors can agree on direction.
- Keep each pull request focused on one behavior or closely related set of
  changes.
- Never include API keys, shell history, personal paths, or other private data.

## Development setup

Platform-specific instructions live in the root [README](README.md) and in each
platform directory. Cross-platform behavior is defined in
[`docs/behavior-spec`](docs/behavior-spec/README.md).

For Linux development:

```sh
cd linux
npm ci
npm test
npm run typecheck
npm run dev
```

For the Windows core:

```sh
cd windows
dotnet test
```

The macOS app requires Xcode and XcodeGen. Run `xcodegen generate`, then build
the `FriendlyTerminal` scheme.

## Pull request quality bar

- Preserve real shell behavior, including interactive programs and resize
  handling.
- Add focused regression tests for parsing, validation, detectors, and other
  pure logic.
- Keep renderer code isolated from Node.js and operating-system access.
- Update user-facing and architecture documentation when behavior changes.
- Run the relevant build, type checker, and test suite before requesting review.
- Avoid unrelated formatting or generated-file churn.

## Reporting bugs

Include the operating system and version, installed FriendlyTerminal version,
shell, exact reproduction steps, expected result, and actual result. Remove
tokens, usernames, hostnames, and sensitive command output from logs and
screenshots.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
