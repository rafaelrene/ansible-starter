#!/usr/bin/env bash

set -euo pipefail

ROOT=$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P
)
TMPDIR_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-install-tests.XXXXXX")
trap 'rm -rf "$TMPDIR_ROOT"' EXIT INT TERM

assert_eq() {
  local expected=$1
  local actual=$2
  local message=$3

  if [[ "$expected" != "$actual" ]]; then
    printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$message" "$expected" "$actual" >&2
    exit 1
  fi
}

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

  cat >"$bin_dir/uname" <<'EOF'
#!/usr/bin/env bash
printf 'Darwin\n'
EOF
  chmod +x "$bin_dir/uname"

  cat >"$bin_dir/xcode-select" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-p" ]]; then
  printf '/Library/Developer/CommandLineTools\n'
  exit 0
fi
exit 1
EOF
  chmod +x "$bin_dir/xcode-select"

  cat >"$bin_dir/git" <<EOF
#!/usr/bin/env bash
set -euo pipefail

log_file=$git_log
printf '%s\n' "\$*" >>"\$log_file"

if [[ "\${1:-}" == "clone" ]]; then
  target=\${@: -1}
  mkdir -p "\$target/bin" "\$target/.git"
  cat >"\$target/bin/dotforge" <<'INNER'
#!/usr/bin/env bash
exit 0
INNER
  chmod +x "\$target/bin/dotforge"
  exit 0
fi

if [[ "\${1:-}" == "-C" ]] && [[ "\${3:-}" == "status" ]] && [[ "\${4:-}" == "--porcelain" ]]; then
  if [[ "\${DOTFORGE_TEST_GIT_STATUS_DIRTY:-0}" == "1" ]]; then
    printf ' M dirty-file\n'
  fi
  exit 0
fi

if [[ "\${1:-}" == "-C" ]] && [[ "\${3:-}" == "fetch" ]]; then
  exit 0
fi

if [[ "\${1:-}" == "-C" ]] && [[ "\${3:-}" == "checkout" ]]; then
  exit 0
fi

if [[ "\${1:-}" == "-C" ]] && [[ "\${3:-}" == "reset" ]]; then
  exit 0
fi

exit 0
EOF
  chmod +x "$bin_dir/git"
}

run_install() {
  local test_name=$1
  shift

  local test_root="$TMPDIR_ROOT/$test_name"
  local home_dir="$test_root/home"
  local bin_dir="$test_root/bin"
  local git_log="$test_root/git.log"

  mkdir -p "$home_dir" "$test_root"
  : >"$git_log"
  make_fake_bin "$bin_dir" "$git_log"

  (
    export HOME="$home_dir"
    export PATH="$bin_dir:$PATH"
    export DOTFORGE_GIT_REPOSITORY="${DOTFORGE_GIT_REPOSITORY-}"
    export DOTFORGE_GIT_BRANCH="${DOTFORGE_GIT_BRANCH-}"
    export DOTFORGE_INSTALL_HOME="${DOTFORGE_INSTALL_HOME-}"
    export DOTFORGE_TEST_GIT_STATUS_DIRTY="${DOTFORGE_TEST_GIT_STATUS_DIRTY-0}"
    "$ROOT/install.sh" "$@"
  )

  if [[ -f "$git_log" ]]; then
    cat "$git_log"
  fi
}

run_install_expect_fail() {
  local test_name=$1
  shift

  local test_root="$TMPDIR_ROOT/$test_name"
  local home_dir="$test_root/home"
  local bin_dir="$test_root/bin"
  local git_log="$test_root/git.log"

  mkdir -p "$home_dir" "$test_root"
  : >"$git_log"
  make_fake_bin "$bin_dir" "$git_log"

  set +e
  local output
  output=$(
    export HOME="$home_dir"
    export PATH="$bin_dir:$PATH"
    export DOTFORGE_GIT_REPOSITORY="${DOTFORGE_GIT_REPOSITORY-}"
    export DOTFORGE_GIT_BRANCH="${DOTFORGE_GIT_BRANCH-}"
    export DOTFORGE_INSTALL_HOME="${DOTFORGE_INSTALL_HOME-}"
    export DOTFORGE_TEST_GIT_STATUS_DIRTY="${DOTFORGE_TEST_GIT_STATUS_DIRTY-0}"
    "$ROOT/install.sh" "$@" 2>&1
  )
  local status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    printf 'FAIL: expected install.sh to fail for %s\n' "$test_name" >&2
    exit 1
  fi

  printf '%s' "$output"
}

default_clone_log=$(run_install default_clone)
assert_contains "clone --branch master https://github.com/rafaelrene/dotforge.git" "$default_clone_log" "default clone should use built-in repo and branch"

cleanup_direct_log=$(run_install cleanup_direct --cleanup-existing)
assert_contains "clone --branch master https://github.com/rafaelrene/dotforge.git" "$cleanup_direct_log" "cleanup flag should be accepted in direct execution"

repo_branch_log=$(run_install repo_branch_override --repo rafaelrene/ansible-starter --branch t3code/migrate-ansible-to-bash-dotforge)
assert_contains "clone --branch t3code/migrate-ansible-to-bash-dotforge https://github.com/rafaelrene/ansible-starter.git" "$repo_branch_log" "cli repo and branch overrides should reach git clone"

custom_home="$TMPDIR_ROOT/custom-home"
install_home_log=$(run_install install_home_override --install-home "$custom_home")
assert_contains "clone --branch master https://github.com/rafaelrene/dotforge.git $custom_home" "$install_home_log" "cli install home should override the default install location"

env_repo=env-owner/env-repo
env_branch=env-branch
env_log=$(
  DOTFORGE_GIT_REPOSITORY=$env_repo DOTFORGE_GIT_BRANCH=$env_branch run_install exported_env
)
assert_contains "clone --branch $env_branch https://github.com/$env_repo.git" "$env_log" "exported environment variables should override defaults"

precedence_log=$(
  DOTFORGE_GIT_REPOSITORY=env-owner/env-repo DOTFORGE_GIT_BRANCH=env-branch run_install precedence --repo cli-owner/cli-repo --branch cli-branch
)
assert_contains "clone --branch cli-branch https://github.com/cli-owner/cli-repo.git" "$precedence_log" "cli arguments should win over exported environment variables"

piped_root="$TMPDIR_ROOT/piped"
mkdir -p "$piped_root/home" "$piped_root/bin"
piped_log="$piped_root/git.log"
: >"$piped_log"
make_fake_bin "$piped_root/bin" "$piped_log"

cat "$ROOT/install.sh" | (
  export HOME="$piped_root/home"
  export PATH="$piped_root/bin:$PATH"
  bash -s -- --repo rafaelrene/ansible-starter --branch t3code/migrate-ansible-to-bash-dotforge --cleanup-existing
)

piped_clone_log=$(cat "$piped_log")
assert_contains "clone --branch t3code/migrate-ansible-to-bash-dotforge https://github.com/rafaelrene/ansible-starter.git" "$piped_clone_log" "bash -s piped execution should honor CLI override arguments"

set +e
unknown_output=$("$ROOT/install.sh" --bogus 2>&1)
unknown_status=$?
set -e
if [[ $unknown_status -eq 0 ]]; then
  printf 'FAIL: unknown argument should fail\n' >&2
  exit 1
fi
assert_contains "Unknown argument: --bogus" "$unknown_output" "unknown arguments should return a clear error"
assert_contains "Usage:" "$unknown_output" "unknown arguments should print usage"
assert_contains "--cleanup-existing" "$unknown_output" "usage output should mention the cleanup flag"

non_git_home="$TMPDIR_ROOT/non-git-home"
mkdir -p "$non_git_home"
non_git_fail_output=$(
  DOTFORGE_INSTALL_HOME=$non_git_home run_install_expect_fail non_git_existing
)
assert_contains "already exists but is not a git checkout" "$non_git_fail_output" "existing non-git directory should still fail without cleanup"

non_git_cleanup_home="$TMPDIR_ROOT/non-git-cleanup-home"
mkdir -p "$non_git_cleanup_home"
printf 'placeholder\n' >"$non_git_cleanup_home/marker"
non_git_cleanup_log=$(
  DOTFORGE_INSTALL_HOME=$non_git_cleanup_home run_install non_git_cleanup --cleanup-existing
)
assert_contains "clone --branch master https://github.com/rafaelrene/dotforge.git $non_git_cleanup_home" "$non_git_cleanup_log" "cleanup flag should remove a blocking non-git directory and reclone"
if [[ -e "$non_git_cleanup_home/marker" ]]; then
  printf 'FAIL: cleanup-existing should remove contents of a blocking non-git directory\n' >&2
  exit 1
fi

dirty_home="$TMPDIR_ROOT/dirty-home"
mkdir -p "$dirty_home/.git"
dirty_fail_output=$(
  DOTFORGE_INSTALL_HOME=$dirty_home DOTFORGE_TEST_GIT_STATUS_DIRTY=1 run_install_expect_fail dirty_existing
)
assert_contains "existing dotforge checkout is dirty" "$dirty_fail_output" "dirty checkout should still fail without cleanup"

dirty_cleanup_home="$TMPDIR_ROOT/dirty-cleanup-home"
mkdir -p "$dirty_cleanup_home/.git"
printf 'dirty\n' >"$dirty_cleanup_home/dirty-file"
dirty_cleanup_log=$(
  DOTFORGE_INSTALL_HOME=$dirty_cleanup_home DOTFORGE_TEST_GIT_STATUS_DIRTY=1 run_install dirty_cleanup --cleanup-existing
)
assert_contains "clone --branch master https://github.com/rafaelrene/dotforge.git $dirty_cleanup_home" "$dirty_cleanup_log" "cleanup flag should remove a dirty checkout and reclone"
assert_not_contains "-C $dirty_cleanup_home fetch" "$dirty_cleanup_log" "dirty cleanup path should not try to update before recloning"
if [[ -e "$dirty_cleanup_home/dirty-file" ]]; then
  printf 'FAIL: cleanup-existing should remove contents of a dirty checkout before recloning\n' >&2
  exit 1
fi

clean_update_home="$TMPDIR_ROOT/clean-update-home"
mkdir -p "$clean_update_home/.git" "$clean_update_home/bin"
cat >"$clean_update_home/bin/dotforge" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$clean_update_home/bin/dotforge"
clean_update_log=$(
  DOTFORGE_INSTALL_HOME=$clean_update_home run_install clean_update --cleanup-existing
)
assert_contains "-C $clean_update_home fetch origin master" "$clean_update_log" "cleanup flag should still update a clean checkout in place"
assert_not_contains "clone --branch master https://github.com/rafaelrene/dotforge.git $clean_update_home" "$clean_update_log" "cleanup flag should not reclone a clean checkout"

file_home="$TMPDIR_ROOT/file-home"
printf 'file\n' >"$file_home"
file_cleanup_log=$(
  DOTFORGE_INSTALL_HOME=$file_home run_install file_cleanup --cleanup-existing
)
assert_contains "clone --branch master https://github.com/rafaelrene/dotforge.git $file_home" "$file_cleanup_log" "cleanup flag should remove a blocking file and reclone"

symlink_home="$TMPDIR_ROOT/symlink-home"
ln -s "$TMPDIR_ROOT/missing-target" "$symlink_home"
symlink_cleanup_log=$(
  DOTFORGE_INSTALL_HOME=$symlink_home run_install symlink_cleanup --cleanup-existing
)
assert_contains "clone --branch master https://github.com/rafaelrene/dotforge.git $symlink_home" "$symlink_cleanup_log" "cleanup flag should remove a blocking symlink and reclone"

arch_bootstrap_log=$(
  test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-install-arch.XXXXXX")
  install_lib="$test_root/install-lib.sh"
  mkdir -p "$test_root/bin"
  trap '/bin/rm -rf "$test_root"' RETURN
  /usr/bin/sed '$d' "$ROOT/install.sh" >"$install_lib"
  (
    set -euo pipefail
    PATH="$test_root/bin"
    source "$install_lib"
    sudo() {
      printf "%s\n" "$*"
      if [[ "$1" == "-n" ]]; then
        return 1
      fi
      return 0
    }
    frontload_arch_sudo_if_needed arch
    ensure_git arch
  )
)
assert_contains "-v" "$arch_bootstrap_log" "install.sh should front-load sudo for Arch bootstrap when git is missing"
assert_contains "pacman -Sy --needed --noconfirm git" "$arch_bootstrap_log" "install.sh should still install git with pacman after upfront sudo"

printf 'install tests passed\n'
