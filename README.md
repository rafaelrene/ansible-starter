# dotforge

`dotforge` replaces the previous Ansible setup with a Bash-based installer and
machine reconciler for macOS and Arch Linux.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/rafaelrene/dotforge/master/install.sh | bash
```

`install.sh` clones or updates the repository into
`~/.local/share/dotforge` and then runs `~/.local/share/dotforge/bin/dotforge`.
This piped bootstrap remains supported for interactive Terminal installs. For
headless macOS runs, Homebrew must already be installed first, and
`DOTFORGE_NONINTERACTIVE=1` does not make the Homebrew bootstrap headless-safe.

For piped installs that need a non-default repository or branch, pass explicit
arguments to `bash`:

```bash
url=https://raw.githubusercontent.com/rafaelrene/ansible-starter/refs/heads/t3code/migrate-ansible-to-bash-dotforge/install.sh
curl -fsSL "$url" | bash -s -- --repo rafaelrene/ansible-starter --branch t3code/migrate-ansible-to-bash-dotforge --cleanup-existing
```

Bootstrap flags:

- `--repo <owner/repo>` selects a non-default GitHub repository.
- `--branch <branch>` selects a non-default branch.
- `--install-home <path>` changes the local checkout path.
- `--cleanup-existing` removes a blocking existing install target before
  re-cloning. This is opt-in and applies only to local path conflicts such as a
  non-git directory, dirty checkout, file, or symlink at the install path.

Bootstrap environment variables:

```bash
DOTFORGE_GIT_REPOSITORY=rafaelrene/dotforge
DOTFORGE_GIT_BRANCH=master
```

When running `curl ... | bash`, shell-local variables do not cross the pipe into
the child `bash` process unless you export them. Use exported environment
variables for direct execution, or prefer the explicit `bash -s -- ...` flags
shown above.

## Commands

```bash
dotforge
dotforge doctor
dotforge pkg add <package-id|brew:name|yay:name>
dotforge pkg rm <package-id|brew:name|yay:name>
dotforge secrets unpack
dotforge secrets pack <path>
```

- Bare `dotforge` performs a full reconcile: packages, managed assets, secrets,
  post-install steps, then `dotforge doctor`.
- `dotforge doctor` verifies package installation, symlink targets, deployed SSH
  secrets, PATH wiring, and post-install state such as Volta-managed Node.
- `dotforge pkg add` and `dotforge pkg rm` update
  `~/.config/dotforge/config`, reconcile packages immediately, then run doctor.
- During reconcile, dotforge detects packages that are already installed and
  skips reinstalling them while still treating them as managed packages.
- Mutating commands collect required interactive input up front so package
  selection, sudo authentication, and the age passphrase are not re-requested
  later in the same run.

## Config

The runtime config is a sourced Bash file at `~/.config/dotforge/config`.

Example:

```bash
# shellcheck shell=bash
DOTFORGE_PACKAGES="fd,fzf,ghostty,neovim,starship,tmux,volta,brew:watch"
```

- Built-in packages use canonical IDs from [`catalog/macos.tsv`](catalog/macos.tsv)
  and [`catalog/arch.tsv`](catalog/arch.tsv).
- Extra packages must be prefixed with `brew:` on macOS or `yay:` on Arch.
- On first run, `dotforge` prompts you to toggle the default package set and
  optionally add extra packages.
- Existing configs are auto-migrated once to add `fzf` and `starship`.

Runtime environment variables:

```bash
DOTFORGE_NONINTERACTIVE=1
DOTFORGE_AGE_PASSPHRASE=...
```

In non-interactive mode, `DOTFORGE_PACKAGES` must already be present in the
environment or config file.

## Secrets

Secrets now live in a single bundle at `secrets/bundle.tar.age`.

Current bundle layout:

```text
opencode/
  gsmcp_token
ssh/
  bitbucket_work
  hetzner
  personal
```

Workflows:

```bash
dotforge secrets unpack
dotforge secrets pack /path/to/unpacked/dir
```

- `unpack` decrypts the bundle into a temp directory and prints the path.
- `pack` expects the same scoped tree, rebuilds `secrets/bundle.tar.age`,
  reapplies the SSH keys locally, and reminds you to commit the updated bundle.
- The current passphrase remains `lucker`.

## Platform Notes

- macOS:
  - `dotforge` requires Xcode Command Line Tools.
  - Homebrew is installed automatically if missing.
  - In non-interactive runs, install Homebrew manually before invoking
    `dotforge`.
- Arch Linux:
  - `install.sh` asks for sudo up front when it must bootstrap `git` with
    `pacman`.
  - `dotforge` bootstraps `yay` if it is missing.
  - `pacman` is used only for bootstrap prerequisites.

## Shell Notes

`dotforge` deploys zsh and starship config and will attempt to switch your login
shell to zsh after install when zsh is selected.

To check your shell state manually:

```bash
ps -p $$ -o comm=
echo "$SHELL"
```

## Managed Paths

`dotforge` owns and replaces these targets if they exist:

- `~/.config/git`
- `~/.config/ghostty`
- `~/.config/graphite`
- `~/.config/nushell`
- `~/.config/nvim`
- `~/.config/custom-nvim-config`
- `~/.config/opencode`
- `~/.config/starship`
- `~/.config/tmux`
- `~/.config/zsh`
- `~/.config/sketchybar` on macOS
- `~/.zshenv`
- `~/.ssh/config`
- `~/.ssh/*.pub`
- `~/.ssh/bitbucket_work`
- `~/.ssh/hetzner`
- `~/.ssh/personal`

## Exceptions

Two absolute paths were intentionally preserved as requested:

- `/Users/rafael/code/.sources/google-cloud-sdk/...`
- `/opt/homebrew/Caskroom/miniconda/base/bin/python`
