---
name: pr-comment-resolver
description: Evaluate and resolve PR review comments. Paste a comment, provide the file context, and I'll assess whether it makes sense, discuss with you if ambiguous, and create an implementation plan if we agree. Use when you have a PR comment to resolve.
---

# PR Comment Resolver

Resolve PR review comments by evaluating their merit, discussing ambiguous cases, and creating implementation plans for agreed-upon changes.

## Input Requirements

Provide:
1. **The comment** - Copy-pasted from your PR (Bitbucket, GitHub, GitLab, etc.)
2. **The file** - Either:
   - Paste the relevant code snippet, OR
   - Provide the file path and I'll read it from the repo

## Workflow

### Step 1: Evaluate the Comment

Before any discussion, I evaluate the comment against these criteria:

- **Technical correctness** - Is the suggestion accurate?
- **Project conventions** - Does it align with existing patterns in the codebase?
- **Significance** - Is this a real improvement or a nitpick?
- **Risk/complexity** - Does it introduce unnecessary risk or complexity?
- **Scope** - Is it asking for something out of scope?

I'll check the codebase for existing patterns before judging. If someone suggests an approach that's already used elsewhere, I'll flag that.

### Step 2: Decision Point

**If the comment clearly doesn't make sense:**
- I tell you why
- We're done—no HTML output

**If the comment is ambiguous:**
- We have a back-and-forth until we reach shared understanding
- You decide whether to implement or dismiss

**If the comment clearly makes sense:**
- We proceed to planning

### Step 3: Implementation Planning (if agreed)

When we agree to implement, I invoke **grill-me** to rigorously plan the implementation:

1. I load the grill-me skill
2. We walk through the design tree together
3. Each decision is resolved with your input
4. We produce a concrete implementation plan

### Step 4: Generate HTML Output

After planning, I create a self-contained HTML file using the template:

**Template:** `template.html` (in this skill directory)
**Location:** `.agents/pr/comment-[YYYY-MM-DD-HHmmss].html`

#### Template Placeholders

Replace these placeholders in the template:

| Placeholder | Description |
|-------------|-------------|
| `{{TIMESTAMP}}` | Generated filename timestamp (e.g., `2024-01-15-143022`) |
| `{{FILE_PATH}}` | Path to the file being discussed |
| `{{COMMENT_TEXT}}` | The original PR comment (escaped for HTML) |
| `{{LINE_NUMBER}}` | Line number if specific, or remove the block |
| `{{VERDICT}}` | "Accepted" or "Dismissed" |
| `{{VERDICT_CLASS}}` | `accept` or `dismiss` |
| `{{EVALUATION_SUMMARY}}` | Brief summary of why we accepted/dismissed |
| `{{EVALUATION_DETAILS}}` | `<li>` items for detailed criteria evaluation |
| `{{RESOLUTION}}` | How we resolved it |
| `{{DISCUSSION_SUMMARY}}` | Summary of back-and-forth if any |
| `{{PLAN_STEPS}}` | Implementation steps with checkboxes |
| `{{FILES_AFFECTED}}` | `<li>` items listing files to modify |
| `{{RISKS_CONSIDERATIONS}}` | Risk items (optional, remove block if none) |

#### Conditional Blocks

- `{{#IF LINE_NUMBER}}...{{/IF_LINE_NUMBER}}` - Include only if line number exists
- `{{#IF EVALUATION_DETAILS}}...{{/IF_EVALUATION_DETAILS}}` - Include only if detailed evaluation
- `{{#IF DISCUSSION_SUMMARY}}...{{/IF_DISCUSSION_SUMMARY}}` - Include only if discussion occurred
- `{{#IF RISKS_CONSIDERATIONS}}...{{/IF_RISKS_CONSIDERATIONS}}` - Include only if risks exist

#### HTML Structure for Dynamic Content

**Plan steps:**
```html
<div class="check-item">
    <div class="checkbox"></div>
    <div class="step-content">
        <div class="step-title">Step title</div>
        <div class="step-details">Details about this step</div>
    </div>
</div>
```

**Evaluation details:**
```html
<li>Criterion: assessment</li>
```

**Files affected:**
```html
<li>path/to/file.yml</li>
```

**Risks:**
```html
<div class="risk-item">
    <div class="risk-title">Risk title</div>
    <div>Risk description</div>
</div>
```

## Example Usage

```
User: Resolve this PR comment

[paste comment here]

[provide file path or paste code snippet]

Agent: [evaluates, discusses if needed, plans with grill-me, generates HTML]
```

## Notes

- One comment at a time for focused evaluation
- The skill is platform-agnostic—works with any PR system
- Only generates HTML for comments we agree to implement
- References grill-me skill for rigorous planning
