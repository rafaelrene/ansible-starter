---
name: create-skill
description: Use when the user wants to create or add a new skill to the agents role, whether they already have its content or need help designing it.
disable-model-invocation: true
---

# Add a skill

Create new skills under `roles/agents/files/skills/`.

Ask one question at a time. For each design decision, include a recommended
answer. If the repository can answer a question, inspect it instead of asking
the user.

Do not create or modify files until the user has reviewed the complete proposed
skill and explicitly approved its creation.

## Gather the skill content

First, ask whether the user already has the complete skill content.

If they do:

1. Ask them to provide it.
2. Preserve the supplied content verbatim.
3. Review it for invalid frontmatter, contradictions, broken references, and
   missing supporting files.
4. Report concerns without silently correcting them.
5. Reuse any supplied frontmatter fields. Ask about required fields that are missing.

If they do not:

1. Grill them about the skill’s behavior, inputs, outputs, boundaries, workflow,
   tools, permissions, and failure handling.
2. Resolve dependencies between decisions one at a time.
3. Continue until no material ambiguity remains and the user agrees with the design.
4. Draft the complete skill body.
5. Show it to the user and revise it until explicitly approved.

## Decide whether supporting files are justified

Always ask once whether the skill needs supporting files.

Keep the skill self-contained by default. Recommend additional files only when
they provide a concrete benefit:

- Use scripts for repeated or deterministic operations where reliability improves.
- Use references for substantial conditional guidance that should not load every
  time.
- Use templates or assets when the skill will copy or adapt them.
- Do not extract content merely because the instructions are long.

For each supporting file:

1. Record its relative path and purpose.
2. Ask whether the user has its complete content or wants to design it together.
3. Preserve supplied content verbatim, or grill and draft missing content.
4. Validate it and report concerns without silently changing it.
5. Preview it in an appropriate form and obtain explicit approval.

Keep every supporting file inside the new skill directory.

## Complete the frontmatter

Reuse valid supplied frontmatter. Only grill fields that are missing or that the
user wants to reconsider.

### Description

The `description` is exclusively a routing rule describing when the model should
load the skill. It does not explain the skill’s workflow.

Grill the user about the requests that should trigger the skill. Ask about
exclusions only when a nearby task could plausibly trigger it incorrectly.

Draft one concise `description` and iterate until the user approves it.

### Model invocation

Ask whether the model may invoke the skill automatically or whether it must be
invoked manually.

Always record the decision explicitly:

```yaml
disable-model-invocation: false
```

for automatic invocation, or:

```yaml
disable-model-invocation: true
```

for manual-only invocation.

### Name

After the body and supporting files are approved, propose exactly three names.

Each name must:

- Use lowercase kebab-case.
- Be shorter than 64 characters.
- Be concise and action-oriented.
- Match the approved skill behavior.

Give a short rationale for each option, clearly recommend one, and allow the user
to provide a custom name.

The frontmatter name and directory name must match.

## Obtain final approval

Show the user:

- The complete directory tree.
- The complete `SKILL.md`.
- Every supporting file.
- Which content was supplied verbatim and which was drafted.
- Any validation concerns.
- Any formatters that will run after creation.

Ask for explicit approval to create the skill.

If the target directory already exists, stop. Offer a different name or ask for
explicit permission to switch to updating the existing skill. Never merge or
overwrite automatically.

## Create and validate

After explicit approval:

1. Create the skill under `roles/agents/files/skills/<name>/`.
2. Write supplied content verbatim.
3. Run any already-configured formatter that applies. Formatter-only changes are
   allowed.
4. Validate the frontmatter, directory name, references, and supporting files. We use `mise` to manage tooling.
5. Run relevant lint checks and focused tests for executable code.
6. Inspect and report the resulting diff.

If validation requires a substantive correction, preview the proposed change
and obtain approval before applying it.

Do not commit or push. Do not run Ansible; tell the user they should run it.
