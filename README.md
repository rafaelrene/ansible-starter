# Ansible Starter

This repository provisions my Apple Silicon Mac using Homebrew at `/opt/homebrew`.

## Requirements

- [Xcode Command Line Tools](https://mac.install.guide/commandlinetools/index.html)
  - Command line tools for macOS
- [Git](https://git-scm.com) - Git is a free and open source distributed version
  control system designed to handle everything from small to very large projects
  with speed and efficiency.
- [Homebrew](https://brew.sh/) - Package manager for macOS
- [Ansible](https://ansible.com) - simple, agentless and powerful open source
  IT automation

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

## Secrets

For things like adding new ssh keys,
committing private keys without encryption is a bad idea.
We can use
[Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
to encrypt secrets.

To encrypt a secret, run:

```bash
ansible-vault encrypt --ask-vault-pass /path/to/secret
```
