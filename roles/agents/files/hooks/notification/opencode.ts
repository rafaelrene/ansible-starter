import type { Plugin } from "@opencode-ai/plugin";

export const NotificationPlugin: Plugin = async ({ client, $ }) => ({
  event: async ({ event }) => {
    const eventType: string = event.type;
    if (
      eventType !== "session.idle" &&
      eventType !== "session.error" &&
      eventType !== "permission.asked" &&
      eventType !== "question.asked"
    ) {
      return;
    }

    const sessionID =
      "sessionID" in event.properties &&
      typeof event.properties.sessionID === "string"
        ? event.properties.sessionID
        : undefined;
    if (!sessionID) {
      void $`"$HOME/.local/bin/agent-notify"`.quiet().nothrow();
      return;
    }

    try {
      const session = await client.session.get({
        path: { id: sessionID },
      });
      if (session.data?.parentID) {
        return;
      }
    } catch {
      // A notification is preferable to silently missing an attention event.
    }

    void $`"$HOME/.local/bin/agent-notify"`.quiet().nothrow();
  },
});
