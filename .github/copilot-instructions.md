# Zephyr — Hard Rules

**Top-tier. Built to serve 100,000+ users from day one. Every decision optimizes for performance at scale — we foresee, not react. Steve Jobs' vision and perfectionism. Toyota's reliability. Zero defects. Direct rival to Chamet — we're taking the majority market share in live social.**

## NEVER:
- Socket.IO — dead. Firebase RTDB only.
- Polling — listen, don't ask.
- New RTDB instances — `FirebaseChatService.instance` or nothing.

## Real-time stack:
| Layer | Tool |
|-------|------|
| Presence / signaling / live events | Firebase RTDB via `FirebaseChatService` |
| Presence → PG sync | Firebase Cloud Function (trigger on `presence/{userId}`) |
| Media (video/audio) | Agora RTC |
| Persistent data / validation | PostgreSQL via REST (`ZephyrApiClient`) |
| Push notifications | FCM (`FcmService` on backend) |

## Presence sync architecture:
- **Single source of truth**: Firebase RTDB `presence/{userId}`
- **PG sync**: Cloud Function triggers on RTDB presence change → writes `status` + `last_seen_at` to PostgreSQL
- **Matchmaking** queries PG: `WHERE status IN ('online', 'away')`
- **Client shows** presence via RTDB listeners (no PG involvement)
- **NEVER** use client-side HTTP heartbeats to sync presence to PG — that's polling in disguise
- **NEVER** duplicate presence state across systems with periodic timers

## Firebase RTDB paths:
- `presence/{userId}` — state (online/inactive/offline/busy/live), lastSeen, roomId
- `direct_calls/{userId}` — call signaling
- `live_rooms/{roomId}/` — comments, reactions, gifts, audience_count, status

## Presence states:
| State | Color | Meaning |
|-------|-------|---------|
| `online` | Green | App in foreground, user active (touched in last 60s) |
| `away` | Yellow | App in foreground, user idle 60s+ (no touches) |
| `busy` | Orange | In an active call |
| `live` | Red | Hosting a stream |
| `offline` | Gray (hidden) | Backgrounded / screen locked / killed / logged out |

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
- Everything is an encapsulated, reusable module. Bulletproof and self-contained.
- Features are composed of modules. e.g the live feature is built from many smaller robust modules.
- Core features — Messaging, Call, Live — must be flawless and performant. Zero compromises.
- Every module is top-tier — works alone, composes cleanly, fails gracefully.
- Modules are Lego. If one isn't good, throw it out and snap in a replacement. No module death-grips another.
- **Jidoka** — Stop the moment something breaks. Fix it now, never pass a defect forward.
- **Genchi Genbutsu** — Go to the source. Read the actual code, check the actual logs, reproduce it yourself.
- **Kaizen** — Every commit leaves the codebase better than you found it.
- **Muda** — Eliminate waste. Dead code, unused abstractions, unnecessary complexity — cut it all.
- **Mura** — Eliminate inconsistency. Same patterns, same conventions, everywhere.
- **Muri** — Don't overburden. If a class does too much, it will break.
- **Poka-yoke** — Mistake-proof the design. Types, null safety, API contracts that can't be misused.
- **Andon** — Make problems visible. Errors surface loud and clear, never swallowed silently.
- **Hansei** — Reflect after every failure. Not just fix — understand what the system should have prevented.
- **Heijunka** — Level the load. Don't let complexity pile up in one place.
- **Just-in-Time** — Build only what you need now. Not what you might need later.
- **Nemawashi** — Think thoroughly, then act fast. Design before code, then ship.
- **5 Whys** — When it breaks, ask "why" five times until you hit the true root cause.

## Audit log:
When auditing a feature, always grade each aspect (A+ to F) and record results here. This is our history of quality.

### Live Streaming — 29 May 2026 — Overall: A+
| Aspect | Grade | Notes |
|--------|-------|-------|
| Architecture | A+ | Agora RTC + RTDB signaling, Cloud Function auto-ends on disconnect. Zero dead code — backend is pure REST (create/join/leave/end/gift/token), all real-time flows through RTDB directly. |
| Reconnection | A | `onConnectionStateChanged` with overlay, token refresh handler |
| Rate limiting | A | 500ms throttle on reactions/comments |
| Error handling | A | User-facing snackbars, graceful fallback |
| Resource cleanup | A | `_ending` guard prevents double-end, proper dispose |
| Code quality | A+ | ValueNotifier for comments, isolated state, no leaks, zero dead endpoints or unused dependencies |

### Messaging / Inbox — 29 May 2026 — Overall: A-
| Aspect | Grade | Notes |
|--------|-------|-------|
| Architecture | A | Firestore messages, RTDB presence, Cloud Function PG sync. Zero polling. |
| Presence | A- | LRU cache (50 cap), 5 states, correct colors |
| Security | A | Block check both directions, anti-spam (5msg/10s + duplicate cooldown) |
| Calling | A- | Full signaling from thread, 30s timeout. Missing: rate preview in thread |
| Performance | A | No polling, debounced search, proper listener cleanup |
| Code quality | A | Dead code gone, clean modules, proper dispose |
| UX | A- | Search for new chat, live preview, inline translation, read receipts. Missing: typing indicator, message reactions |

### Call (Direct + Random) — 29 May 2026 — Overall: A
| Aspect | Grade | Notes |
|--------|-------|-------|
| Architecture | A+ | REST matchmaking + RTDB signaling + Agora RTC. Socket.IO fully purged from codebase (packages removed). Random inherits from Direct (shared DirectCallScreen). |
| Signaling | A | writeRinging → listen accept/decline → 30s timeout → Agora. Block check both directions. Cloud Function safety net on signal deletion. |
| Economy/Billing | A- | Tick every 15s, billing starts only when partner joins, insufficient balance auto-ends call |
| Reconnection | A | `onConnectionStateChanged` with overlay, `onTokenPrivilegeWillExpire` with renewal |
| Error handling | A | User-facing snackbars (balance, connection, Agora errors), graceful fallback, tick retries silently |
| Resource cleanup | A- | `_disposed` guard, engine release in dispose, timers cancelled. `_leaveWithResult` for random mode. |
| Security | A | Block check both directions, backend validates all billing, service key on internals |
| Code quality | A+ | Random = thin matchmaking layer inheriting DirectCallScreen. Zero duplication. Zero dead code. |

### IAP / Billing — 2 Jun 2026 — Overall: A+
| Aspect | Grade | Notes |
|--------|-------|-------|
| Architecture | A+ | Flutter `in_app_purchase` → backend verify-purchase → credit coins. StoreKit 2 + Google Play Billing. Direct credit endpoint blocked in production. |
| Apple verification | A+ | Full JWS certificate chain verified against Apple G3 root CA via `decodeTransaction()`. Forged receipts detected as `CertificateValidationError`. Validates bundleId + productId cryptographically. Rejects revoked transactions. |
| Google verification | A+ | Publisher API token verification via `google-auth-library`. Validates packageName + productId. Checks `purchaseState === 0` (purchased) and `consumptionState === 0` (unconsumed). |
| Refund handling | A+ | Apple ASNS V2 webhook + Google RTDN webhook. `processRefund()` deducts coins immediately, records `iap_refund` transaction. Idempotent (skips if already refunded). Balance can go negative (fraud protection). |
| Idempotency | A+ | `iap_purchases.transaction_id` UNIQUE constraint. Check-before-insert prevents double-credit. Race conditions caught by PostgreSQL. |
| Retry safety | A+ | `completePurchase()` only called after backend confirms credit. Failed verifications retry on next app launch automatically. |
| Production hardening | A+ | `POST /v1/economy/purchase-coins` blocked unless `ALLOW_FAKE_PURCHASES=true`. Flutter fallback restricted to `kDebugMode`. |
| Code quality | A+ | Singleton `IapService.instance`. Clean separation: Flutter handles store interaction, backend handles all validation + crediting. Zero trust on client. |

### Onboarding — 2 Jun 2026 — Overall: A
| Aspect | Grade | Notes |
|--------|-------|-------|
| Architecture | A | Google + Apple login → `onboardedAt` null-check → profile setup or straight to home. Backend `COALESCE(onboarded_at, NOW())` on PATCH /me. No guest login. |
| Login flow | A | Google Sign-In + Apple Sign-In. Buttons disabled during loading. Proper error display. API offline warning on startup. |
| Profile setup | A | Nickname (2-20 chars, control chars blocked, emoji allowed), country picker, language dropdown. Keyboard dismiss on tap. Semantics labels. |
| Backend | A | `issueGoogleSession` / `issueAppleSession` → find-or-create user → JWT. `updateMe` sets `onboarded_at` via COALESCE on first profile save. Backfill migration for existing users. |
| Session restore | A | `main.dart` checks `profile.onboardedAt != null` — already-onboarded users skip setup on re-login. |
| Security | A | Google token verified server-side with audience check. Apple token verified via JWKS. No client-side trust. |
| Code quality | A | Clean separation: `onboarding_page.dart` (login), `profile_setup_screen.dart` (setup). No dead code. Proper dispose. |

