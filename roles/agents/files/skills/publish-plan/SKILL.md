---
name: publish-plan
description: Use when planning is complete and the model is about to recap an agreed plan, or when the user asks to present or publish an already-finished plan. Do not use while material decisions or unresolved questions remain.
disable-model-invocation: false
---

# Publish a finished plan

Turn an agreed plan into a consistent, self-contained HTML document, publish it, and return its link.

This skill presents finished planning work. It does not plan, grill, resolve decisions, or expand scope.

## Preconditions

Use this skill only when planning is complete and the next response would recap the agreed plan.

Before continuing, confirm that:

- No material questions remain.
- The user has agreed to the decisions and scope.
- The plan describes one coherent implementation effort.
- The conversation contains enough detail to write every required section.

If material questions remain, return to planning. Do not publish an incomplete plan.

If the work contains several independently deliverable, pull-request-sized tracks, return to planning and split it into smaller plans. Do not turn one oversized plan into a project tracker.

## Preserve the agreement

Preserve the decisions, reasoning, scope, sequence, constraints, and verification discussed during planning.

You may reorganize agreed information to make the document easier to read. Do not:

- Add decisions that were never discussed.
- Reopen settled decisions.
- Invent implementation details to fill space.
- Add generic advice or decorative content.
- Replace missing information with assumptions.

## Required structure

Every plan must contain these sections in this order:

1. Why this change
2. Desired outcome
3. Implementation plan
4. Verification
5. After launch

"After launch" must always be the final visible section.

Use "After launch" for useful follow-up work after implementation and deployment. If there are no recommendations, write:

> No follow-up recommendations or improvements at this time.

Do not add an unresolved-questions section. Unresolved questions mean the plan is not ready for this skill.

## Implementation content

The implementation section is adaptable. Organize it around the actual work instead of forcing every plan into the same internal outline.

Use implementation steps when sequence matters. Include agreed decisions, affected areas, data flow, dependencies, warnings, or boundaries where they help someone implement the plan.

Keep the plan compact. Implementation steps are not checkboxes.

Add code examples or pseudo-diffs when they make APIs, schemas, configuration, data flow, or structural changes easier to understand. Skip examples that merely repeat prose.

Label each example as exact code, pseudo-code, or pseudo-diff. Include a filename or language label when known.

## Checkboxes

Use interactive checkboxes only for:

- Manual actions the agent cannot perform.
- Actions in external services or interfaces.
- Manual or external verification.

Keep agent-executable checks such as formatting, linting, type checks, tests, and builds as plain-text verification instructions.

Give every checkbox a unique, stable `data-check-id`. Use short semantic IDs that remain meaningful if nearby content moves.

The template saves checkbox state in `localStorage`, namespaces it by plan ID, restores it after refresh, and provides a reset control. Do not rewrite this behavior.

If the plan has no manual actions, remove the manual-check markup. The progress controls must remain hidden.

## Build the document

Create a temporary directory with `mktemp -d`. Copy [`template.html`](template.html) into it using a descriptive `.html` filename.

Replace every template marker with plan content. Duplicate or remove the supplied content blocks as needed.

Generate a stable plan ID from the project, topic, and confirmation date. Keep it independent of the published URL.

Keep the output self-contained:

- Inline all CSS and JavaScript.
- Use system fonts.
- Do not load external stylesheets, scripts, fonts, images, or other assets.
- Normal reference links are allowed.
- Escape plan content correctly for HTML.
- Remove all template instructions and unused sample blocks.

Keep the template's visual system and embedded JavaScript unchanged. Do not invent a new theme for each plan.

The layout uses one fixed alignment line for the primary content in every section. Plain prose, the first outcome, step titles, and verification content must begin on that line. Internal padding is reserved for secondary content such as code blocks and callouts.

Use information, warning, and danger callouts only when the plan contains information deserving that weight.

## Validate before publication

Do not publish until all checks pass:

- All five required sections exist in the required order.
- "After launch" is the final visible content.
- No unresolved questions appear.
- No template markers or instructional comments remain.
- The document contains no external assets.
- Every checkbox has a unique `data-check-id`.
- Only manual or external work uses checkboxes.
- The HTML, CSS, and JavaScript are self-contained.
- The page has no horizontal overflow on a narrow viewport.
- The embedded JavaScript has no known runtime errors.
- The primary content alignment remains consistent across sections.

Render the file with an available browser preview and inspect desktop and narrow layouts. If browser preview is unavailable, run the deterministic structural checks and continue.

Fix presentation or transcription errors before publishing. If fixing the document would require a new planning decision, stop and return to planning.

## Publish

Run:

```sh
npx @rraf/pp "<path-to-plan-file.html>"
```

If publication fails, retry the same command once.

On success, return only the clickable published-plan link. Do not include a Markdown recap, local path, or extra commentary.

On a second failure, preserve the temporary HTML file and report:

- The publication error.
- The absolute local path to the generated plan.

Never claim publication succeeded without a returned link.
