---
name: publish-plan
description: Use when planning is complete and the model is about to recap, publish, revise, or republish an agreed plan. Do not use while material decisions or unresolved questions remain.
disable-model-invocation: false
---

# Publish or revise a finished plan

Turn an agreed plan into a consistent, self-contained HTML document, publish it,
and return its link. When the plan changes, update the same draft and preserve
why each published version changed.

This skill presents finished planning work. It does not plan, grill, resolve
decisions, or expand scope.

## Preconditions

Use this skill only when planning is complete and the next response would recap
the agreed plan.

Before continuing, confirm that:

- No material questions remain.
- The user has agreed to the decisions and scope.
- The plan describes one coherent implementation effort.
- The conversation contains enough detail to write every required section.
- A revision has enough context to describe its final changes and rationale.

If material questions remain, return to planning. Do not publish an incomplete
plan.

If the work contains several independently deliverable, pull-request-sized
tracks, return to planning and split it into smaller plans. Do not turn one
oversized plan into a project tracker.

## Preserve the agreement

Preserve the decisions, reasoning, scope, sequence, constraints, and verification
discussed during planning.

You may reorganize agreed information to make the document easier to read. Do
not:

- Add decisions that were never discussed.
- Reopen settled decisions.
- Invent implementation details to fill space.
- Add generic advice or decorative content.
- Replace missing information with assumptions.

## Choose the publication mode

Use initial publication when the plan has not been published before. Create v1
with no change-history section.

Use revision publication when updating an existing published plan. Before
building it:

1. Identify the prior plan URL and draft ID. If either cannot be identified
   reliably, ask the user for the prior link.
2. Read the current published document and resolve its current `pp` version and
   timestamps. The response header `x-pp-draft-version` or
   `npx @rraf/pp list --json` can provide the authoritative version.
3. Preserve the plan ID, Created At value, and existing history. Do not edit old
   history entries. Prepend the new entry so history remains newest first.
4. Set the document version to the current `pp` version plus one. Preserve
   Created At, and use one current local timestamp for Updated At and the new
   history entry.
5. Publish to the same draft with `--draft`. Never let a fresh temporary path
   silently create a separate draft.

If a document predates revision tracking, use its current `pp` version instead
of backfilling. When that version is later than v1, add one collapsed entry:

> Versions 2-N: History unavailable because this plan predates revision tracking.

Then add normal entries for new versions. If document metadata and `pp` disagree,
or the current version cannot be resolved, stop and ask rather than guessing.

## Required structure

An initial plan must contain these sections in this order:

1. Why this change
2. Desired outcome
3. Implementation plan
4. Verification
5. After launch

A revision uses the same order with Change history between Verification and
After launch. "After launch" must always be the final visible section.

Use "After launch" for useful follow-up work after implementation and
deployment. If there are no recommendations, write:

> No follow-up recommendations or improvements at this time.

Do not add an unresolved-questions section. Unresolved questions mean the plan
is not ready for this skill.

## Plan metadata

Every plan header must show:

- Version as `vN`.
- Created At as a full local timestamp with timezone.
- Updated At in the same format.

Use matching Created At and Updated At timestamps on v1. Preserve Created At on
every revision and update only Updated At. Add machine-readable ISO values to
the template's `time` elements.

Generate the plan ID once from the project, topic, and creation date. Keep it
independent of the published URL and preserve it across revisions so checkbox
state survives. Existing semantic check IDs retain their state; new checks get
new IDs.

## Change history

Starting with v2, add one entry for every successful republish, including
wording-only corrections. Each normal entry contains:

- A transition label in the form `vN-1 → vN`, with only `vN-1` linked to
  its immutable `pp` snapshot.
- The publication timestamp in the local timezone.
- A concise list of concrete changes from the previous version.
- The rationale agreed during replanning.

Record only changes that reached the published revision. Omit rejected ideas and
intermediate edits. Do not add an author, status, full diff, or v1 entry.

History is append-only. Never rewrite an older entry when later decisions reverse
it. The collapsed legacy entry is the only exception to the one-entry-per-version
shape and does not need a snapshot link or timestamp.

## Implementation content

Organize the implementation section around the actual work instead of forcing
every plan into the same internal outline. Use steps when sequence matters.
Include agreed decisions, affected areas, data flow, dependencies, warnings, or
boundaries where they help implementation.

Keep the plan compact. Implementation steps are not checkboxes.

Add code examples or pseudo-diffs when they make APIs, schemas, configuration,
data flow, or structural changes easier to understand. Skip examples that repeat
the prose. Label each example as exact code, pseudo-code, or pseudo-diff, and
include a filename or language label when known.

## Checkboxes

Use interactive checkboxes only for:

- Manual actions the agent cannot perform.
- Actions in external services or interfaces.
- Manual or external verification.

Keep agent-executable checks such as formatting, linting, type checks, tests, and
builds as plain-text verification instructions.

Give every checkbox a unique, stable `data-check-id`. Use short semantic IDs that
remain meaningful if nearby content moves.

The template saves checkbox state in `localStorage`, namespaces it by plan ID,
restores it after refresh, and provides a reset control. Do not rewrite this
behavior.

If the plan has no manual actions, remove the manual-check markup. The progress
controls must remain hidden.

## Build the document

Create a temporary directory with `mktemp -d`. Copy
[`template.html`](template.html) into it using a descriptive `.html` filename.
Build revisions from the current template, carrying the agreed plan content and
preserved metadata forward.

Replace every template marker with plan content. Duplicate or remove the
supplied content blocks as needed. On v1, remove the Change history section and
number After launch as section 05. On revisions, retain Change history and number
After launch as section 06.

Keep the output self-contained:

- Inline all CSS and JavaScript.
- Use system fonts.
- Do not load external stylesheets, scripts, fonts, images, or other assets.
- Normal reference links are allowed.
- Escape plan content correctly for HTML.
- Remove all template instructions and unused sample blocks.

Keep the template's visual system and embedded JavaScript unchanged. Do not
invent a new theme for each plan.

Stack each section heading above its content with 16px of separation. Keep the
page full-width and preserve the inner layouts for outcomes, steps,
verification, history, tables, code blocks, and callouts.

Use information, warning, and danger callouts only when the plan contains
information deserving that weight.

## Validate before publication

Do not publish until all checks pass:

- The required sections exist in the correct order for the publication mode.
- "After launch" is the final visible content.
- v1 has matching Created At and Updated At values and no history.
- A revision preserves Created At and the plan ID, updates Updated At, and has
  the expected history entry.
- Normal history entries are newest first and link their previous-version label
  to the preceding immutable snapshot.
- No unresolved questions appear.
- No template markers or instructional comments remain.
- The document contains no external assets.
- Every checkbox has a unique `data-check-id`.
- Only manual or external work uses checkboxes.
- The HTML, CSS, and JavaScript are self-contained.
- The page has no horizontal overflow on a narrow viewport.
- The embedded JavaScript has no known runtime errors.
- Every section heading appears above its content with the expected spacing.

Render the file with an available browser preview and inspect desktop and narrow
layouts. If browser preview is unavailable, run the deterministic structural
checks and continue.

Fix presentation or transcription errors before publishing. If fixing the
document would require a new planning decision, stop and return to planning.

## Publish

For an initial publication, run:

```sh
npx @rraf/pp "<path-to-plan-file.html>"
```

For a revision, run:

```sh
npx @rraf/pp "<path-to-plan-file.html>" --draft "<draft-id>"
```

If publication fails, retry the same command once. Confirm that the returned
draft ID and version match the intended revision before reporting success.

On success, return only the clickable published-plan link. Do not include a
Markdown recap, local path, or extra commentary.

On a second failure, or when the returned draft or version is unexpected,
preserve the temporary HTML file and report:

- The publication error or mismatch.
- Why publication failed, based on the command output.
- How to fix the failure, with concrete next steps.
- The absolute local path to the generated plan.

If the command output does not reveal the cause, say that the cause is unknown
and report the specific diagnostic or user action needed to identify it. Do not
guess.

Never claim publication succeeded without a returned link.
