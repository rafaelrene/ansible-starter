#!/usr/bin/env bash

set -euo pipefail

ROOT=$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P
)
TMPDIR_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-self-tests.XXXXXX")
trap 'rm -rf "$TMPDIR_ROOT"' EXIT INT TERM

assert_contains() {
  local needle=$1
  local haystack=$2
  local message=$3

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'FAIL: %s\nmissing: %s\noutput: %s\n' "$message" "$needle" "$haystack" >&2
    exit 1
  fi
}

assert_not_contains() {
  local needle=$1
  local haystack=$2
  local message=$3

  if [[ "$haystack" == *"$needle"* ]]; then
    printf 'FAIL: %s\nunexpected: %s\noutput: %s\n' "$message" "$needle" "$haystack" >&2
    exit 1
  fi
}

make_fake_bin() {
  local bin_dir=$1
  local git_log=$2
  mkdir -p "$bin_dir"

  cat >"$bin_dir/git" <<EOF
#!/usr/bin/env bash
set -euo pipefail

log_file=$git_log
printf '%s\n' "\$*" >>"\$log_file"

if [[ "\${1:-}" == "-C" ]]; then
  shift 2
fi

case "\${1:-}" in
  rev-parse)
    printf '.git\n'
    ;;
  symbolic-ref)
    if [[ "\${DOTFORGE_TEST_GIT_DETACHED:-0}" == "1" ]]; then
      exit 1
    fi
    printf '%s\n' "\${DOTFORGE_TEST_GIT_BRANCH:-master}"
    ;;
  fetch)
    exit 0
    ;;
  status)
    printf '%s' "\${DOTFORGE_TEST_GIT_STATUS_SHORT:-}"
    ;;
  log)
    printf '%s' "\${DOTFORGE_TEST_GIT_LOCAL_COMMITS:-}"
    ;;
  reset)
    exit 0
    ;;
  clean)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF
  chmod +x "$bin_dir/git"
}

make_fake_root() {
  local root_dir=$1

  mkdir -p "$root_dir/.git"
  ln -s "$ROOT/bin" "$root_dir/bin"
  ln -s "$ROOT/lib" "$root_dir/lib"
}

run_self() {
  local test_name=$1
  shift

  local test_root="$TMPDIR_ROOT/$test_name"
  local fake_root="$test_root/root"
  local home_dir="$test_root/home"
  local bin_dir="$test_root/bin"
  local git_log="$test_root/git.log"

  mkdir -p "$test_root" "$home_dir"
  : >"$git_log"
  make_fake_bin "$bin_dir" "$git_log"
  make_fake_root "$fake_root"

  (
    export HOME="$home_dir"
    export PATH="$bin_dir:$PATH"
    export DOTFORGE_TEST_GIT_BRANCH="${DOTFORGE_TEST_GIT_BRANCH:-master}"
    export DOTFORGE_TEST_GIT_STATUS_SHORT="${DOTFORGE_TEST_GIT_STATUS_SHORT-}"
    export DOTFORGE_TEST_GIT_LOCAL_COMMITS="${DOTFORGE_TEST_GIT_LOCAL_COMMITS-}"
    "$fake_root/bin/dotforge" "$@"
  )

  cat "$git_log"
}

run_self_expect_fail() {
  local test_name=$1
  shift

  local test_root="$TMPDIR_ROOT/$test_name"
  local fake_root="$test_root/root"
  local home_dir="$test_root/home"
  local bin_dir="$test_root/bin"
  local git_log="$test_root/git.log"

  mkdir -p "$test_root" "$home_dir"
  : >"$git_log"
  make_fake_bin "$bin_dir" "$git_log"
  make_fake_root "$fake_root"

  set +e
  local output
  output=$(
    export HOME="$home_dir"
    export PATH="$bin_dir:$PATH"
    export DOTFORGE_TEST_GIT_BRANCH="${DOTFORGE_TEST_GIT_BRANCH:-master}"
    export DOTFORGE_TEST_GIT_STATUS_SHORT="${DOTFORGE_TEST_GIT_STATUS_SHORT-}"
    export DOTFORGE_TEST_GIT_LOCAL_COMMITS="${DOTFORGE_TEST_GIT_LOCAL_COMMITS-}"
    "$fake_root/bin/dotforge" "$@" 2>&1
  )
  local status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    printf 'FAIL: expected dotforge to fail for %s\n' "$test_name" >&2
    exit 1
  fi

  printf '%s' "$output"
}

update_log=$(run_self clean_update self update)
assert_contains "fetch origin master" "$update_log" "self update should fetch the current branch from origin"
assert_contains "reset --hard origin/master" "$update_log" "self update should reset the checkout to the fetched branch head"
assert_not_contains "clean -fd" "$update_log" "self update should not remove untracked files"

dirty_output=$(
  DOTFORGE_TEST_GIT_STATUS_SHORT=$' M lib/self.sh\n?? scratch.txt\n' \
  DOTFORGE_TEST_GIT_LOCAL_COMMITS=$'abc123 local commit\n' \
  run_self_expect_fail dirty_update self update
)
assert_contains "Refusing to update the dotforge checkout while local changes are present." "$dirty_output" "self update should fail when local state would interfere"
assert_contains "Local file changes:" "$dirty_output" "self update should report tracked and untracked file changes"
assert_contains " M lib/self.sh" "$dirty_output" "self update should include git status output"
assert_contains "?? scratch.txt" "$dirty_output" "self update should include untracked files in the failure output"
assert_contains "Unpushed commits:" "$dirty_output" "self update should report local-only commits"
assert_contains "abc123 local commit" "$dirty_output" "self update should include local-only commit summaries"

clean_log=$(run_self destructive_clean self clean)
assert_contains "fetch origin master" "$clean_log" "self clean should fetch the current branch from origin"
assert_contains "reset --hard origin/master" "$clean_log" "self clean should discard tracked changes and local commits"
assert_contains "clean -fd" "$clean_log" "self clean should remove untracked files while keeping ignored files untouched"

printf 'self tests passed\n'
