# dotforge

`dotforge` replaces the previous Ansible setup with a Bash-based installer and
machine reconciler for macOS and Arch Linux.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/rafaelrene/dotforge/master/install.sh | bash
```

`install.sh` clones or updates the repository into
`~/.local/share/dotforge` and then runs `~/.local/share/dotforge/bin/dotforge`.

Bootstrap environment variables:

```bash
DOTFORGE_GIT_REPOSITORY=rafaelrene/dotforge
DOTFORGE_GIT_BRANCH=master
```

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

## Config

The runtime config is a sourced Bash file at `~/.config/dotforge/config`.

Example:

```bash
# shellcheck shell=bash
DOTFORGE_PACKAGES="fd,ghostty,neovim,tmux,volta,brew:watch"
```

- Built-in packages use canonical IDs from [`catalog/macos.tsv`](catalog/macos.tsv)
  and [`catalog/arch.tsv`](catalog/arch.tsv).
- Extra packages must be prefixed with `brew:` on macOS or `yay:` on Arch.
- On first run, `dotforge` prompts you to toggle the default package set and
  optionally add extra packages.

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
- Arch Linux:
  - `dotforge` bootstraps `yay` if it is missing.
  - `pacman` is used only for bootstrap prerequisites.

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
