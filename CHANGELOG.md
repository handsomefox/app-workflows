# Changelog

## 0.2.0

- Run the checks inside `release.yml`, on the commit it resolved, alongside the builds. A release takes about four minutes less. Each app's release caller drops its `checks` job and passes `no-default-features-lib` to `release.yml` instead.
- Run Clippy on Windows in its own job beside the tests, so the slowest CI job finishes sooner.
- Detect unused dependencies before anything compiles.
- Upload the packed archives without compressing them again.

## 0.1.1

- Find the built executables when an app ships only one platform. 0.1.0 failed every Windows-only release while packing it.

## 0.1.0

- Check and release apps through reusable `ci.yml` and `release.yml` workflows, in place of a copy of each workflow and its scripts in every app.
- Build and ship a Linux archive only for apps that set `linux`, and check the glibc floor with the app's own script.
- Publish only from a pushed tag or a tag named in a manual run. A manual run started from a tag without naming one is a dry run.
- Refuse to release a version that is not `<major>.<minor>.<patch>`, which app-update would never install.
- Look the release tag up as `refs/tags/<tag>`, so a branch with the same name cannot stand in for it.
- Leave concurrency to each app's caller workflows, so a release run never shares a group with a CI run.
