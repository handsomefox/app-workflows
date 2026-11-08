# app-workflows

[![Lint](https://github.com/handsomefox/app-workflows/actions/workflows/lint.yml/badge.svg)](https://github.com/handsomefox/app-workflows/actions/workflows/lint.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Reusable GitHub Actions workflows that check and release Rust desktop apps. Each app keeps two short caller workflows and pins this repository by commit.

These apps use it:

- [DLSS Updater](https://github.com/handsomefox/dlss-updater)
- [Elden Ring Save Guard](https://github.com/handsomefox/eldenring-backuptool)
- [osu!lazer Cleaner](https://github.com/handsomefox/osu-lazer-cleaner)
- [Windows Cleaner](https://github.com/handsomefox/win-cleaner)
- [Windows Toolkit](https://github.com/handsomefox/win-toolkit)

## The workflows

`ci.yml` runs actionlint, shellcheck, and `zizmor --persona pedantic` on the app's workflows. It runs `cargo fmt`, the tests, and Clippy on Ubuntu and Windows, plus `cargo machete` and `cargo audit`. CI tools come from release binaries pinned by SHA-256.

`release.yml` resolves the version, builds the Windows executable, and optionally a Linux one in a pinned Ubuntu 22.04 container. It packs versioned archives with a `SHA256SUMS`, verifies them twice, attests them, and publishes the GitHub release, with the app's `CHANGELOG.md` section as its notes. A manual run without a tag is a dry run that publishes nothing.

The archives are what [app-update](https://github.com/handsomefox/app-update) installs from. Each holds `<bin>-<version>-<platform>/<bin>[.exe]`, `README.md`, and `LICENSE`, in a `<bin>-<version>-<platform>.zip`, or `.tar.gz` on Linux.

## Inputs

| Input | Workflow | Meaning |
| --- | --- | --- |
| `package` | release | The Cargo package whose version is released and whose binary is built. |
| `bin` | release; ci with `linux-floor-check` | The executable name without `.exe`. |
| `release-tag` | release | For a manual run, the existing tag to publish. Empty is a dry run. |
| `linux` | release | Also build and ship `linux-x86_64`. |
| `linux-floor-check` | both | A script in the app that checks the Linux binary's glibc floor. In CI, setting it adds the container build. |
| `submodules` | both | Passed to `actions/checkout`, such as `recursive`. |
| `no-default-features-lib` | ci | Also test and lint the library with `--no-default-features`. |
| `ref` | ci | The commit or ref to check. Empty means the event's commit. |

## Use it

`.github/workflows/ci.yml` in the app:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    # Weekly, so a new RustSec advisory fails the audit without waiting for a push.
    - cron: "23 5 * * 1"
  workflow_dispatch:

permissions: {}

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  ci:
    permissions:
      contents: read
    uses: handsomefox/app-workflows/.github/workflows/ci.yml@<commit> # v0.1.0
```

`.github/workflows/release.yml` in the app:

```yaml
name: Release

on:
  push:
    tags:
      - "v*"
  workflow_dispatch:
    inputs:
      release_tag:
        description: Existing v* tag to rebuild and publish; leave empty for a dry run
        required: false
        type: string

permissions: {}

concurrency:
  group: release-${{ inputs.release_tag || github.ref }}
  cancel-in-progress: false

jobs:
  checks:
    permissions:
      contents: read
    uses: handsomefox/app-workflows/.github/workflows/ci.yml@<commit> # v0.1.0
    with:
      ref: ${{ inputs.release_tag && format('refs/tags/{0}', inputs.release_tag) || github.sha }}

  release:
    needs: checks
    permissions:
      attestations: write # Publish provenance for each release asset.
      contents: write # Create the GitHub release and upload assets.
      id-token: write # Request the OIDC identity used for provenance.
    uses: handsomefox/app-workflows/.github/workflows/release.yml@<commit> # v0.1.0
    with:
      package: toolkit-app
      bin: win-toolkit
      release-tag: ${{ inputs.release_tag }}
```

Pin both lines to the same full commit SHA, with the tag in the comment. Dependabot's `github-actions` updater moves the pin when a new tag is released.

## License

Licensed under the [MIT License](LICENSE).
