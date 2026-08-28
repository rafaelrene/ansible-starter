This repository is Rene's Ansible starter for provisioning his development
environment on macOS and WSL. `main.yml` applies an ordered set of roles to the
local machine.

## Core principles

- Treat checked-in role files as the source of truth for generated and
  distributed configuration.
- Keep changes in the role that owns the affected tool or configuration.

## Glossary

- Agent role: The `roles/agents` role distributes shared rules, skills, and
  agent-specific configuration for Codex, Claude, OpenCode, and Pi.
- Shared skill: A directory under `roles/agents/files/skills` that the agent role
  symlinks into every configured agent's skill directory.

## Code guide

- `main.yml` defines the roles and their application order.
- Each role keeps orchestration in `roles/<role>/tasks` and source files in
  `roles/<role>/files`.
- `roles/agents/tasks/agent_skills.yml` discovers and distributes shared skills.
  Its destinations are defined in `roles/agents/vars/main.yml`.

## Commands

- `bash ./run.sh`: Install Ansible collections and apply the playbook to the
  local machine. Rene must run this command.

## Project preferences

- Do not run Ansible. Tell Rene which Ansible command he should run instead.

## Footguns

- `run.sh` changes the local machine and prompts for sudo and Ansible Vault
  credentials.
- Distributed agent skills are symlinks into this repository. Editing an
  installed skill edits the checked-in source through that symlink.

## Task completion requirements

- Run applicable format, lint, validation, and test checks that do not execute
  the Ansible playbook.
- Tell Rene when end-to-end verification requires him to run `bash ./run.sh`.
