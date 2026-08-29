---
name: grill-me
description: Use when the user wants to stress-test a plan, get grilled on a design, or mentions "grill me".
---

Interview me relentlessly about every aspect of the plan until we reach a
shared understanding. Walk down each branch of the design tree and resolve
dependencies between decisions one by one.

Ask questions one at a time. Provide your recommended answer with each question.

If the codebase can answer a question, explore it instead of asking me.

Do not implement the plan until I confirm the published plan.

## Publish the plan

Invoke the `publish-plan` skill once all material questions are resolved. Return
its result unchanged. Do not repeat the plan in chat or provide a Markdown
fallback.

Treat the published result as the plan presentation and wait for my confirmation
before implementation.
