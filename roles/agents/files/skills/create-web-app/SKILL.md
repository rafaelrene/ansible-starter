---
name: create-web-app
description: Use when the user explicitly invokes create-web-app to add a Chromium web-app launcher to Rene's Ansible configuration.
disable-model-invocation: true
---

# Create a web app

Create a Raycast web-app launcher from the bundled template.

## Inputs

Require:

- App name
- App URL

If either input is missing, ask for it one at a time.

Normalize the app name:

1. Replace newlines with spaces.
2. Collapse repeated whitespace and trim surrounding whitespace.
3. Append ` Web App` unless it already has that suffix.
4. Replace `/` with `-` in the filename only.

Require a complete URL beginning with `http://` or `https://`. Reject malformed
URLs and other schemes. Preserve the accepted URL exactly.

## Create the launcher

The destination is always:

`/Users/rafael/code/.personal/ansible/roles/web-apps/files/`

Render `templates/web-app` by replacing:

- `__APP_NAME__` with the normalized display name.
- `__APP_URL__` with the URL, escaped safely for a single-quoted zsh string.

Show the resolved filename and URL before writing.

If the destination already exists, stop and ask for explicit permission before
overwriting it.

Make the created file executable. Validate it with `zsh -n`. Report the created
path and validation result.

Do not commit, push, or run Ansible.
