#!/usr/bin/env python3

import os
import pty
import select
import subprocess
import sys


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: age_passphrase.py <encrypt|decrypt> <age args...>", file=sys.stderr)
        return 2

    mode = sys.argv[1]
    cmd = ["age"] + sys.argv[2:]
    passphrase = os.environ.get("DOTFORGE_AGE_PASSPHRASE", "")
    if not passphrase:
        print("DOTFORGE_AGE_PASSPHRASE is required", file=sys.stderr)
        return 2

    master_fd, slave_fd = pty.openpty()
    process = subprocess.Popen(cmd, stdin=slave_fd, stdout=slave_fd, stderr=slave_fd, close_fds=True)
    os.close(slave_fd)

    buffer = ""
    prompts_written = 0
    while True:
        ready, _, _ = select.select([master_fd], [], [], 0.1)
        if master_fd in ready:
            chunk = os.read(master_fd, 4096)
            if not chunk:
                break
            text = chunk.decode("utf-8", errors="replace")
            sys.stdout.write(text)
            sys.stdout.flush()
            buffer += text

            if "Enter passphrase" in buffer:
                os.write(master_fd, (passphrase + "\n").encode("utf-8"))
                prompts_written += 1
                buffer = ""
            elif mode == "encrypt" and "Confirm passphrase" in buffer:
                os.write(master_fd, (passphrase + "\n").encode("utf-8"))
                prompts_written += 1
                buffer = ""

        if process.poll() is not None:
            break

    os.close(master_fd)
    return process.wait()


if __name__ == "__main__":
    raise SystemExit(main())
