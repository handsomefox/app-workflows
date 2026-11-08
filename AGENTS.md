# Repository guidelines

The [README](README.md) covers what the workflows do and how an app calls them. This page covers the rules for changing them.

## Five apps release through these workflows

DLSS Updater, Elden Ring Save Guard, osu!lazer Cleaner, Windows Cleaner, and Windows Toolkit call `ci.yml` and `release.yml`, pinned by commit. A release published from here is what every installed copy of an app updates to. Change it conservatively.

## Do not break the release contract

The tag format, the archive names and layout, and `SHA256SUMS` are a contract with every installed copy, because [app-update](https://github.com/handsomefox/app-update) installs from them. The README lists them. Renaming any part strands users on the version before the rename.

Keep these checks:

- **Releasing.** Only a pushed `v*` tag, or a tag named in a manual run, publishes. Anything else is a dry run.
- **Version format.** A release version must be `<major>.<minor>.<patch>` and match the tag.
- **The built commit.** Every job, the checks included, uses the commit `meta` resolved, and `publish` confirms the tag still names it.
- **Checks before packing.** `assemble` runs only after `ci.yml` and every requested build pass.
- **Verification.** The archives are verified once after packing and again in `publish`, on the downloaded copy.
- **Notes.** A release cannot go out without a non-empty `CHANGELOG.md` section.

## Shared steps live once per file

Each former script is one step, defined once with a YAML anchor (`&name`) and reused with an alias (`*name`). A reused step reads what differs between jobs from job-level `env`, such as `CI_TOOLS`, `VERSION`, or `PLATFORMS`. Anchors do not reach across files, so the Linux container steps appear in both `ci.yml` and `release.yml`. Change both together.

The steps run inline, not from a checked-out script, because a reusable workflow cannot find out which commit of this repository it runs at. Inline steps always match the pinned commit. actionlint runs shellcheck on every `run:` block.

## Release a change

1. Push to `main`. The Lint workflow must pass.
2. Add a `## <version>` section to `CHANGELOG.md`, then push an annotated `v<version>` tag. Tag before any app pins the commit: zizmor checks each pin's `# v<version>` comment against the tag.
3. Prove the tag on one app first. Point Windows Toolkit's two callers at the tagged commit, push, and run its Release workflow by hand with no tag. That dry run builds, packs, and verifies without publishing.
4. If the dry run fails, fix the workflow and release the next patch version. Never move a published tag.
5. Create a GitHub release from the `CHANGELOG.md` section.
6. In each other app, move both caller pins to the tagged commit under one commit subject, or merge Dependabot's pull requests.

## Bump CI tool pins by hand

The `Install CI tools` step in `ci.yml` and the install step in `lint.yml` download cargo-audit, cargo-machete, actionlint, and zizmor. Each archive is checked against a pinned SHA-256 before anything is extracted. The Linux jobs pin the `ubuntu:22.04` image by digest and `rustup-init` by hash. Dependabot cannot bump any of these.

To bump a tool, change its row and take the new hash from the digest GitHub records for the asset:

```sh
gh release view <tag> -R <owner>/<repo> --json assets --jq '.assets[] | select(.name == "<asset>") | .digest'
```

`docker buildx imagetools inspect ubuntu:22.04` prints the image's current digest. `https://static.rust-lang.org/rustup/archive/<version>/x86_64-unknown-linux-gnu/rustup-init.sha256` holds the hash for a rustup release.

Run actionlint and `zizmor --persona pedantic` before you push a workflow change.
