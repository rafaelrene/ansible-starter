#!/usr/bin/python

from __future__ import annotations

import json
import os
import tempfile
from pathlib import Path
from typing import Any


def update_hooks(
    document: dict[str, Any],
    events: list[str],
    command: str,
    present: bool,
    matchers: dict[str, str] | None = None,
) -> tuple[dict[str, Any], bool]:
    updated = json.loads(json.dumps(document))
    hooks = updated.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise TypeError("the hooks property must be an object")

    for event, groups in list(hooks.items()):
        if not isinstance(groups, list):
            raise TypeError(f"hooks.{event} must be an array")

        retained_groups = []
        for group in groups:
            if not isinstance(group, dict):
                raise TypeError(f"hooks.{event} entries must be objects")
            handlers = group.get("hooks", [])
            if not isinstance(handlers, list):
                raise TypeError(f"hooks.{event}[].hooks must be an array")

            retained_handlers = [
                handler
                for handler in handlers
                if not (isinstance(handler, dict) and handler.get("command") == command)
            ]
            if retained_handlers:
                retained_group = dict(group)
                retained_group["hooks"] = retained_handlers
                retained_groups.append(retained_group)

        if retained_groups:
            hooks[event] = retained_groups
        else:
            hooks.pop(event, None)

    if present:
        for event in events:
            groups = hooks.setdefault(event, [])
            managed_group: dict[str, Any] = {
                "hooks": [
                    {
                        "type": "command",
                        "command": command,
                        "async": True,
                    }
                ]
            }
            if matchers and event in matchers:
                managed_group["matcher"] = matchers[event]
            groups.append(managed_group)

    if not hooks:
        updated.pop("hooks", None)

    return updated, updated != document


def read_document(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        document = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read valid JSON from {path}: {error}") from error
    if not isinstance(document, dict):
        raise TypeError(f"{path} must contain a JSON object")
    return document


def write_document(path: Path, document: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o600
    fd, temporary_path = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "w") as temporary_file:
            json.dump(document, temporary_file, indent=2)
            temporary_file.write("\n")
        os.chmod(temporary_path, mode)
        os.replace(temporary_path, path)
    finally:
        if os.path.exists(temporary_path):
            os.unlink(temporary_path)


def main() -> None:
    from ansible.module_utils.basic import AnsibleModule

    module = AnsibleModule(
        argument_spec={
            "path": {"type": "path", "required": True},
            "events": {"type": "list", "elements": "str", "required": True},
            "command": {"type": "str", "required": True},
            "matchers": {"type": "dict", "default": {}},
            "state": {
                "type": "str",
                "choices": ["present", "absent"],
                "default": "present",
            },
        },
        supports_check_mode=True,
    )

    path = Path(os.path.expanduser(module.params["path"]))
    try:
        document = read_document(path)
        updated, changed = update_hooks(
            document,
            module.params["events"],
            module.params["command"],
            module.params["state"] == "present",
            module.params["matchers"],
        )
        if changed and not module.check_mode:
            write_document(path, updated)
    except (TypeError, ValueError) as error:
        module.fail_json(msg=str(error))

    module.exit_json(changed=changed)


if __name__ == "__main__":
    main()
