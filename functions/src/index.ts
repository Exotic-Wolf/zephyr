import { onValueDeleted, onValueUpdated } from "firebase-functions/v2/database";
import { defineString } from "firebase-functions/params";
import { logger } from "firebase-functions";

// ── Config ───────────────────────────────────────────────────────────────────
const apiBaseUrl = defineString("API_BASE_URL", {
  description: "Zephyr API base URL (e.g. https://zephyr-api-wr1s.onrender.com)",
  default: "https://zephyr-api-wr1s.onrender.com",
});

const serviceKey = defineString("SERVICE_KEY", {
  description: "Shared secret for internal service-to-service calls",
});

// ── Cloud Function: End call session when RTDB signal node is deleted ────────
export const onCallSignalDeleted = onValueDeleted(
  {
    ref: "direct_calls/{userId}",
    region: "asia-southeast1",
  },
  async (event) => {
    const userId = event.params.userId;
    const deletedData = event.data.val();

    if (!deletedData || typeof deletedData !== "object") {
      logger.info(`direct_calls/${userId} deleted but had no data`);
      return;
    }

    const sessionId = deletedData.sessionId as string | undefined;
    if (!sessionId) {
      logger.info(`direct_calls/${userId} deleted but no sessionId`);
      return;
    }

    logger.info(`direct_calls/${userId} deleted — ending session ${sessionId}`);

    try {
      const res = await fetch(
        `${apiBaseUrl.value()}/v1/internal/end-call-session`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Service-Key": serviceKey.value(),
          },
          body: JSON.stringify({
            sessionId,
            reason: "signal_deleted",
          }),
        },
      );

      if (!res.ok) {
        const body = await res.text();
        logger.error(`API returned ${res.status}: ${body}`);
      } else {
        logger.info(`Session ${sessionId} ended successfully`);
      }
    } catch (err) {
      logger.error("Failed to call API:", err);
    }
  },
);

// ── Cloud Function: Auto-end live room when host presence leaves 'live' ──────
export const onPresenceChanged = onValueUpdated(
  {
    ref: "presence/{userId}",
    region: "asia-southeast1",
  },
  async (event) => {
    const userId = event.params.userId;
    const before = event.data.before.val();
    const after = event.data.after.val();

    const prevState = before?.state as string | undefined;
    const newState = after?.state as string | undefined;
    const roomId = before?.roomId as string | undefined;

    // Only fire when transitioning FROM 'live' to something else
    if (prevState !== "live" || newState === "live") {
      return;
    }

    if (!roomId) {
      logger.info(`presence/${userId} left 'live' but had no roomId`);
      return;
    }

    logger.info(
      `presence/${userId} went from 'live' to '${newState}' — ending room ${roomId}`,
    );

    try {
      const res = await fetch(
        `${apiBaseUrl.value()}/v1/internal/end-room`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Service-Key": serviceKey.value(),
          },
          body: JSON.stringify({
            roomId,
            hostUserId: userId,
          }),
        },
      );

      if (!res.ok) {
        const body = await res.text();
        logger.error(`API returned ${res.status}: ${body}`);
      } else {
        logger.info(`Room ${roomId} ended successfully`);
      }
    } catch (err) {
      logger.error("Failed to call API:", err);
    }
  },
);
