---
name: repo-context
description: Inspect upstream library or framework source from local agent-sources repos after current-repo inspection is exhausted. Use rcx list and rcx resolve to stay inside ~/.local/share/agent-sources, search with rg, prefer source over examples/docs, ask the user on missing or ambiguous repos, and never browse the web.
---

Use this skill only for upstream source inspection from local `agent-sources` repos.

## When To Use

Use this skill when:
- the current repo was already inspected and did not answer the question well enough
- the user explicitly wants upstream library/framework truth from source code

Do not use this skill to inspect the current project repo.

## Boundaries

- Search only inside `~/.local/share/agent-sources`
- Only inspect repos known to `rcx`
- Never browse the web
- Never inspect arbitrary repos outside `agent-sources`
- Never auto-clone or auto-fetch
- If evidence is inconclusive, stop and report uncertainty

## Repo Selection

1. If the caller already knows the exact repo id, use it.
2. Otherwise run `rcx resolve <query>`.
3. If exactly one repo is returned, use it.
4. If several repos are returned, ask the user to choose.
5. If no repo is returned, ask the user whether they want to add one with `rcx <repo-or-url>`.

Use `rcx list` when you need inventory context.

## Search Order

Search in this order:
1. implementation source
2. tests if clearly relevant
3. examples or sample apps
4. optional in-repo docs

Source code wins over examples and docs.

Use plain shell tools. Prefer `rg` for search.

## Output Contract

Return a balanced structured report:

### Conclusion
- short answer
- practical guidance only if supported by evidence

### Evidence
- key files inspected
- what each file proved

### Confidence
- `high`, `medium`, or `low`

### Could Not Verify
- concrete unknowns
- unclear behavior or missing proof

### Suggested Next Step
- only when blocked by missing repo or ambiguity

When surfacing file references, use absolute paths.
