import { onValueDeleted, onValueUpdated } from "firebase-functions/v2/database";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineString } from "firebase-functions/params";
import { logger } from "firebase-functions";
import { initializeApp } from "firebase-admin/app";
import { getDatabase } from "firebase-admin/database";

initializeApp();

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

// ── Scheduled: Reap stale presence entries every 5 minutes ───────────────────
export const reapStalePresence = onSchedule(
  {
    schedule: "every 5 minutes",
    region: "asia-southeast1",
  },
  async () => {
    const db = getDatabase();
    const snapshot = await db.ref("presence").get();

    if (!snapshot.exists()) {
      logger.info("No presence entries to check");
      return;
    }

    const now = Date.now();
    const staleThreshold = 5 * 60 * 1000; // 5 minutes
    const entries = snapshot.val() as Record<
      string,
      { state?: string; lastSeen?: number; roomId?: string }
    >;

    let reaped = 0;

    for (const [userId, data] of Object.entries(entries)) {
      if (!data || data.state === "offline") continue;

      const lastSeen = data.lastSeen ?? 0;
      if (now - lastSeen < staleThreshold) continue;

      // Stale entry — force offline
      logger.info(
        `Reaping stale presence: ${userId} (state=${data.state}, lastSeen=${lastSeen})`,
      );

      // If they were live with a roomId, end the room
      if (data.state === "live" && data.roomId) {
        try {
          await fetch(`${apiBaseUrl.value()}/v1/internal/end-room`, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "X-Service-Key": serviceKey.value(),
            },
            body: JSON.stringify({
              roomId: data.roomId,
              hostUserId: userId,
            }),
          });
        } catch (err) {
          logger.error(`Failed to end room for ${userId}:`, err);
        }
      }

      // Set presence to offline
      await db.ref(`presence/${userId}`).set({
        state: "offline",
        lastSeen: now,
      });

      reaped++;
    }

    logger.info(`Reap complete: ${reaped} stale entries cleaned`);
  },
);
