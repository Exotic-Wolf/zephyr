# Zephyr — Hard Rules

## NEVER use:
- **Socket.IO** — removed. All real-time is Firebase RTDB.
- **Polling** — use Firebase RTDB listeners or ValueNotifier.
- **New RTDB instances** — ONE source of truth: `FirebaseChatService.instance`.

## Real-time stack:
| Layer | Tool |
|-------|------|
| Presence / signaling / live events | Firebase RTDB via `FirebaseChatService` |
| Media (video/audio) | Agora RTC |
| Persistent data / validation | PostgreSQL via REST (`ZephyrApiClient`) |
| Push notifications | FCM (`FcmService` on backend) |

## Firebase RTDB paths:
- `presence/{userId}` — state, lastSeen, roomId
- `direct_calls/{userId}` — call signaling
- `live_rooms/{roomId}/` — comments, reactions, gifts, audience_count, status

## Before writing code:
1. Real-time? → `FirebaseChatService.instance` (RTDB)
2. Media? → Agora RTC
3. Validation / economy / DB write? → REST endpoint
4. Never create a new Firebase or RTDB instance anywhere
5. Never add socket.io, web_socket_channel, or any socket library
6. Never poll — listen

## Economy:
- Gifts: 60% receiver, 40% platform. ~5500 coins/USD.
- Backend validates ALL transactions. Client writes RTDB event AFTER successful API response.

## Dev philosophy:
- Simple, precise, top-tier. No over-complication.
- Build the minimum that does the job perfectly.
- Don't add abstractions unless clearly needed.
- Find the real root cause — don't layer fixes on symptoms.
