#!/bin/bash
# Runs the packaging, verification, and release-notes steps of release.yml against
# fixtures. The steps are read out of release.yml itself, so this tests the code that
# runs, not a copy of it. Needs bash, yq v4, zip, unzip, and GNU tar and sha256sum.
#
#   tests/release-steps.sh
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
workflow="$root/.github/workflows/release.yml"
failures=0

# Prints the run: block of the step named $2 in job $1.
step() {
  yq -e ".jobs.$1.steps[] | select(.name == \"$2\") | .run" "$workflow"
}
package=$(step assemble "Package release archives")
verify=$(step assemble "Verify release assets")
notes=$(step meta "Extract the release notes")

# A fresh app checkout with built executables for the platforms named in $@.
fixture() {
  local dir
  dir=$(mktemp -d)
  mkdir "$dir/bin" "$dir/tmp"
  printf 'readme\n' > "$dir/README.md"
  printf 'license\n' > "$dir/LICENSE"
  for platform in "$@"; do
    case "$platform" in
      windows-*) printf 'exe\n' > "$dir/bin/tool.exe" ;;
      linux-*) printf 'elf\n' > "$dir/bin/tool" ;;
    esac
  done
  echo "$dir"
}

# Runs a step's script in $dir the way GitHub runs a bash step.
run_step() {
  local dir=$1 script=$2
  (cd "$dir" && BIN=tool VERSION=1.2.3 PLATFORMS=${PLATFORMS:-windows-x86_64} \
    TAG=${TAG-v1.2.3} RUNNER_TEMP="$dir/tmp" \
    bash --noprofile --norc -e -o pipefail -c "$script") > "$dir/out.log" 2>&1
}

pass() { echo "ok:   $1"; }
fail() {
  echo "FAIL: $1"
  sed 's/^/      /' "$2/out.log"
  failures=$((failures + 1))
}
expect_ok() { if run_step "$2" "$3"; then pass "$1"; else fail "$1" "$2"; fi; }
expect_error() { if run_step "$2" "$3"; then fail "$1 (expected an error)" "$2"; else pass "$1"; fi; }

# Packaging and verification.
dir=$(fixture windows-x86_64)
expect_ok "packs a Windows-only release" "$dir" "$package"
expect_ok "verifies a Windows-only release" "$dir" "$verify"
files=$(find "$dir/dist" -mindepth 1 -printf '%f\n' | sort)
if [[ "$files" == $'SHA256SUMS\ntool-1.2.3-windows-x86_64.zip' ]]; then
  pass "a Windows-only release holds one zip and SHA256SUMS"
else
  echo "FAIL: unexpected files in dist: ${files//$'\n'/ }"
  failures=$((failures + 1))
fi

export PLATFORMS="windows-x86_64 linux-x86_64"
dir=$(fixture windows-x86_64 linux-x86_64)
expect_ok "packs a Windows and Linux release" "$dir" "$package"
expect_ok "verifies a Windows and Linux release" "$dir" "$verify"

dir=$(fixture windows-x86_64)
expect_error "refuses to pack a missing Linux executable" "$dir" "$package"

dir=$(fixture windows-x86_64 linux-x86_64)
run_step "$dir" "$package"
# Change the first digit to a different one. Writing a fixed digit would leave
# a checksum that already starts with it valid.
sed -i '1{s/^0/1/;t;s/^./0/}' "$dir/dist/SHA256SUMS"
expect_error "rejects a checksum that does not match" "$dir" "$verify"

dir=$(fixture windows-x86_64 linux-x86_64)
run_step "$dir" "$package"
printf 'not a checksum line\n' >> "$dir/dist/SHA256SUMS"
expect_error "rejects a malformed SHA256SUMS line" "$dir" "$verify"

dir=$(fixture windows-x86_64 linux-x86_64)
run_step "$dir" "$package"
touch "$dir/dist/extra.txt"
expect_error "rejects an unexpected file beside the archives" "$dir" "$verify"

dir=$(fixture windows-x86_64 linux-x86_64)
run_step "$dir" "$package"
rm "$dir/dist/tool-1.2.3-linux-x86_64.tar.gz"
expect_error "rejects a missing archive" "$dir" "$verify"
unset PLATFORMS

# Release notes.
dir=$(fixture)
printf '# Changelog\n\n## 1.2.3\n\n- A change.\n\n## 1.2.2\n\n- Older.\n' > "$dir/CHANGELOG.md"
expect_ok "extracts the version's notes" "$dir" "$notes"
if [[ "$(cat "$dir/tmp/notes.md")" == "- A change." ]]; then
  pass "the notes stop at the next version"
else
  echo "FAIL: notes were: $(cat "$dir/tmp/notes.md")"
  failures=$((failures + 1))
fi

dir=$(fixture)
printf '# Changelog\n\n## 1.2.2\n\n- Older.\n' > "$dir/CHANGELOG.md"
expect_error "refuses a version with no notes section" "$dir" "$notes"

dir=$(fixture)
printf '# Changelog\n\n## 1.2.3\n\n\n## 1.2.2\n\n- Older.\n' > "$dir/CHANGELOG.md"
expect_error "refuses an empty notes section" "$dir" "$notes"

dir=$(fixture)
TAG="" expect_ok "a dry run needs no notes" "$dir" "$notes"

if ((failures > 0)); then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
