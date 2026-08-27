---
name: grill-me
description: Interview me relentlessly about a plan or design until reaching shared understanding, capture stable project context in AGENTS.md, and publish the finished plan. Use when the user wants to stress-test a plan, get grilled on a design, or mentions "grill me".
---

Interview me relentlessly about every aspect of the plan until we reach a
shared understanding. Walk down each branch of the design tree and resolve
dependencies between decisions one by one.

Ask questions one at a time. Provide your recommended answer with each question.

If the codebase can answer a question, explore it instead of asking me.

Do not implement the plan until I confirm the published plan. Updating
`AGENTS.md` as described below is a planning artifact and the only project write
allowed before that confirmation.

## Maintain project context

While exploring the codebase and asking questions, collect stable facts that
belong in the project's local `AGENTS.md`.

Use the Git repository root as the project root. If there is no Git repository
but the workspace has an identifiable project root, use that. If neither exists,
skip this step without blocking the plan.

Inspect the root documentation, manifests, configuration, and the code areas
relevant to the plan. Do not crawl every file looking for exhaustive project
documentation. Before ending the interview, ask about any template section that
cannot be supported by repository evidence. Never invent project rules. If I
confirm that a section has no project-specific guidance, write
`- No additional project-specific guidance.`

Once all material questions are resolved and the decisions and scope are agreed,
update the project root's `AGENTS.md` before publishing the plan:

1. Read and follow [`assets/AGENTS.md`](assets/AGENTS.md). Replace every
   `{{PLACEHOLDER}}` with project-specific content.
2. If `AGENTS.md` does not exist, create it from the template.
3. If it exists, preserve every relevant instruction and move it into the
   closest standard section. Keep an extra section only when moving its content
   would change its meaning. Never silently delete or weaken existing guidance.
4. Make the smallest justified edit. Add missing sections, fix stale facts found
   during inspection, and merge new knowledge. Do not rewrite correct prose for
   style alone.

Keep glossary entries alphabetical. Include project-specific domain language,
internal names, abbreviations, and terms whose local meaning differs from normal
usage. Exclude common language and standard technology names unless the project
uses them unusually. Format each entry as `- Term: One-sentence explanation.`

## Publish the plan

Invoke the `publish-plan` skill after the `AGENTS.md` pass. Return its result
unchanged. Do not repeat the plan in chat or provide a Markdown fallback.

Treat the published result as the plan presentation and wait for my confirmation
before implementation.
