import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { spawn } from "node:child_process";

const notify = () => {
  const notifier = spawn(`${process.env.HOME}/.local/bin/agent-notify`, [], {
    detached: true,
    stdio: "ignore",
  });
  notifier.unref();
};

export default function notificationExtension(pi: ExtensionAPI) {
  pi.on("agent_settled", notify);
}
