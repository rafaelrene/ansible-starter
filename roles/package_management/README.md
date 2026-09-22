# Homebrew packages

Edit `files/Brewfile` to manage taps, formulae, and casks. It is the authoritative
list: the role installs missing packages, upgrades outdated packages, then removes
unlisted Homebrew formulae, casks, and taps. Required dependencies are retained.
Cleanup only runs after installation succeeds and is checked for leftovers.
Casks are uninstalled without `--zap`, preserving their user data.

Third-party taps declare `trusted: true` in the Brewfile because cleanup also
replaces Homebrew's trust store with the declarations in this file.

Homebrew's normal upgrade rules apply, including pinned formulae and casks that
use `version :latest` or update themselves.

From the repository root, preview removals without accepting a cleanup prompt:

```bash
brew bundle cleanup --formula --cask --tap \
  --file=roles/package_management/files/Brewfile </dev/null
```

The preview exits with status 1 when unlisted packages remain. Apply the role as
part of the playbook with `bash ./run.sh`.
