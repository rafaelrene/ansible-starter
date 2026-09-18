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

## Agent notifications

T3Code supplies notifications for local and remote threads. On each device,
choose **Settings → Thread notifications → Notifications with sound** and
allow notification permission. Keep T3Code open. Use the desktop app or HTTPS;
plain HTTP works only on localhost.

Run `bash ./run.sh` on the Mac to remove the old agent hooks, notifier, and
SSH journal listener, and unload its LaunchAgent. Other agent hooks and
settings are preserved.

## Secrets

For things like adding new ssh keys,
committing private keys without encryption is a bad idea.
We can use [Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html) to encrypt secrets.

To encrypt a secret, run:

```bash
ansible-vault encrypt --ask-vault-pass /path/to/secret
```
