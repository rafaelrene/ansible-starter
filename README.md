# Ansible Starter

This is my starter repo where I have all the setup I need to get up and running quickly.

## Requirements

### macOS

- [Xcode Command Line Tools](https://mac.install.guide/commandlinetools/index.html) - Command line tools for MacOS
- [Git](https://git-scm.com) - Git is a free and open source distributed version
  control system designed to handle everything from small to very large projects
  with speed and efficiency.
- [Homebrew](https://brew.sh/) - The Missing Package Manager for macOS (or Linux)
- [Ansible](https://ansible.com) - simple, agentless and powerful open source
  IT automation

### Windows

Use WSL. So far I haven't had the time to configure WSL, so we just assume arch linux.

## How to run

With [Nix](https://nixos.org/download/) and [devenv](https://devenv.sh/) installed,
enter the project's development environment to make Ansible and Ansible Vault available:

```bash
devenv shell
```

Then apply the playbook:

```bash
bash ./run.sh
```

This will take care of intalling any ansible dependencies, setting up ssh keys,
installing system packages and configuring everything.

## Othinus agent notifications

On macOS, `bash ./run.sh` installs a background listener alongside the existing
local agent notifier. Othinus's NixOS configuration must also include the journal
publisher in `config/agents/hooks/notification/common.sh`.

- `~/.local/bin/othinus-agent-notify-listen` is a symlink to
  `roles/agents/files/hooks/notification/othinus-listen.sh`.
- `~/Library/LaunchAgents/dev.rafr.othinus-agent-notify.plist` starts it at login
  and restarts it after exit, at most once per 30 seconds.
- The listener uses `ssh othinus`. Your SSH configuration owns the hostname,
  username, identity, routing, and host-key verification. No connection details
  are hardcoded in the listener.

Before testing delivery, verify that the alias connects as the Othinus user
running the agents and authenticates without a prompt:

```sh
ssh othinus
ssh -o BatchMode=yes othinus '/run/current-system/sw/bin/journalctl --user --lines=0 --no-pager'
```

The checked-in alias currently uses `User othinus`; it must resolve to the
correct account in your applied SSH configuration. The listener does not
override or repair the alias.

Each new `attention` journal event calls the existing `~/.local/bin/agent-notify`
to show “Agent needs attention”. Local Mac agents continue using that same
notifier. Forwarding runs while you are logged in, even when T3Code is closed.
It sends no prompt text, project names, or click-through links.

SSH connection attempts time out after ten seconds and an unresponsive
connection is detected after approximately 45 seconds while awake. On
reconnection, historical events are skipped. An event already buffered in a
surviving connection can arrive late after sleep. macOS notification permissions
and Focus still apply.

Check the installed service:

```sh
plutil -lint ~/Library/LaunchAgents/dev.rafr.othinus-agent-notify.plist
launchctl print gui/$(id -u)/dev.rafr.othinus-agent-notify
```

For SSH errors, run `~/.local/bin/othinus-agent-notify-listen` in a terminal.
That starts a second listener, so stop it with Ctrl-C after diagnosis to avoid
duplicate popups. Reapplying an unchanged playbook leaves the service running;
changes to the listener source or plist reload it.

After applying both configurations, complete a short task and trigger a
permission request in a fresh Othinus-backed T3Code session. Confirm each causes
both an Othinus popup and a Mac popup, without answering the permission request.
Disconnect the Mac, generate an Othinus notification, reconnect, and confirm
the missed event is skipped and a new event arrives. Repeat after sleep/wake
and verify local Mac agent notifications still work.

To stop forwarding until the next login or playbook application:

```sh
launchctl bootout gui/$(id -u)/dev.rafr.othinus-agent-notify
```

## Secrets

For things like adding new ssh keys,
committing private keys without encryption is a bad idea.
We can use [Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html) to encrypt secrets.

To encrypt a secret, run:

```bash
ansible-vault encrypt --ask-vault-pass /path/to/secret
```
