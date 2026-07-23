---
name: grill-me
description: Interview me relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

Interview me relentlessly about every aspect of this plan until
we reach a shared understanding. Walk down each branch of the design tree,
resolving dependencies between decisions one-by-one.
For each question, provide your recommended answer.

Ask the questions one at a time.

If a question can be answered by exploring the codebase, explore the codebase instead.

Once shared understanding is reached, spawn adversarial sub-agent
reviewer that will double check the plan and provide feedback.
Provide feedback in the form of another grill-me session until all
points are addressed and plan is approved.
Reviewer sub-agent must be a flagship model of other company.
Use claude when main agent is from openai and vice versa.
High reasoning, fast mode disabled.

Don't jump to the implementation by yourself.
Always present the plan first and wait for my confirmation.
