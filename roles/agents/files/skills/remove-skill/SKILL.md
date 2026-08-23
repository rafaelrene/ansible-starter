---
name: remove-skill
description: Use when the user wants to remove or delete an existing skill from the agents role and from every agent it is symlinked into.
disable-model-invocation: true
---

# Remove a skill

Delete a skill from `roles/agents/files/skills/` and from every agent it is
symlinked into.

Ansible distributes skills by discovering directories, so it never removes
anything. Deleting only the source leaves a dangling symlink in each agent's
skills directory. This skill removes both sides.

Do not delete or modify anything until the user has approved the removal plan.

## Resolve the target

Confirm which skill to remove. If the user did not name one, or the name does
not match a directory, list `roles/agents/files/skills/` and ask.

The source may already be gone while symlinks remain. If
`roles/agents/files/skills/<name>` does not exist, say so and keep going —
there is probably still a link to clean up.

## Find every symlink

Read `roles/agents/tasks/agent_skills.yml` and derive the destination
directories from its symlink tasks. That file is the only source of truth for
where skills are distributed. Do not assume a fixed set of agents, and do not
rely on a list written down anywhere else.

In each destination, inspect the entry named `<name>`. Plan to delete it only
when it is a symlink whose target is inside `roles/agents/files/skills/`. If it
is a real directory, or a symlink pointing elsewhere, leave it and report it. It
did not come from this role.

## Find stale references

Grep the repository for the skill's name, excluding its own directory. Expect
hits in:

- `roles/agents/files/AGENTS.md`
- `roles/agents/files/agent_configs/opencode/opencode.jsonc`
- other `SKILL.md` bodies that invoke the skill

Record each hit with its file, line, and surrounding text. Do not edit yet.

## Scan for other dangling links

While walking the destination directories, note any other entry whose target no
longer exists. These are leftovers from earlier removals. Keep them separate
from the target skill.

A dangling symlink fails an existence test but passes a symlink test. Check
with `test -L` and read the target with `readlink`.

## Present the plan

Show:

- The source directory to delete, and how many files it holds.
- Each symlink to delete, by full path.
- Each destination being skipped, and why.
- Every stale reference, with file and line.
- Every unrelated dangling symlink.

Ask once for approval to delete the source directory and its symlinks.

Reference edits and unrelated dangling links are separate decisions. Do not
fold them into that approval.

## Execute

1. Delete the source directory.
2. Delete each planned symlink.
3. For each stale reference, show the exact edit you propose and apply it only
   after the user agrees. Removing a mention from prose may need rewording
   rather than deletion.
4. Offer to delete the unrelated dangling symlinks. Remove them only if the
   user agrees.

## Verify and report

Confirm the source directory is gone and that no entry named `<name>` remains
in any destination directory. Re-scan for dangling links and report what is
left.

Show the resulting `git diff` and `git status`.

Ansible does not need to run. Discovery is by directory, so a removed skill
simply stops being distributed. Do not run it. Do not commit or push.
