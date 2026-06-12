# Zephyr Product Model And Economy

Product rules, compliance boundaries, monetization model, pricing, levels, gifts, premium live, and video/call mechanics.

## Content & Store Compliance Rules

Zephyr is an 18+ social video product. Adult age rating is a gate, not a permission slip for unmoderated sexual content.

Product law:

- App Store / Play Store listing, screenshots, onboarding, public feeds, normal live, and premium live must not promote nudity, pornographic content, prostitution, or explicitly sexual services.
- Normal live has a no-nudity rule.
- Premium live is paid access to a more intimate group experience, but still must follow platform rules, reporting, blocking, moderation, and host enforcement.
- Direct/random calls are private adult interactions between consenting adults, but the app must still provide report, block, ban, and safety tooling.
- User-generated content surfaces must include terms acceptance, report, block, moderation response, and a clear abuse channel before production launch.
- Gifts are never "maybe." Gifts are a reusable monetization primitive across inbox, normal live, premium live, direct calls, and random calls.

---

## Scaling Plan

| Users | Infrastructure | Est. cost |
|---|---|---|
| 0–5K | Current Render free tier | ~$0 |
| 5K–10K | Upgrade API to Standard + Redis Starter | ~$40/mo |
| 10K–100K | 3x instances + Pro Postgres + PgBouncer | ~$200/mo |
| 100K+ | Migrate to AWS/GCP with auto-scaling | Variable |

**Pre-production must-do:** Upgrade API from free (sleeps after 15 min) to Standard ($25/mo).

---

## Coin Packages (In-App Purchase)

Users buy coins with real money. These are the available packages:

| Price (USD) | Coins | Coins per dollar |
|-------------|-------|-----------------|
| $2.99 | 16,500 | ~5,519 |
| $5.99 | 33,000 | ~5,509 |
| $9.99 | 55,000 | ~5,505 |
| $29.99 | 165,000 | ~5,502 |
| $59.99 | 330,000 | ~5,501 |
| $99.99 | 550,000 | ~5,501 |

**Ratio is flat** — no meaningful bulk discount. ~5,500 coins per dollar across all tiers.

---

## Direct Calls (caller → receiver, per minute)

Receiver sets their own rate based on their level. They earn 60% of what the caller pays.

These are product default rate options. Backend DB/env config owns the active options; mobile renders the options returned by API.

| Tier | Caller pays (coins/min) | Receiver earns (sparks/min) | Platform keeps |
|------|------------------------|----------------------------|----------------|
| ≤Lv3 | 2,100 | 1,260 | 840 |
| Lv4  | 3,200 | 1,920 | 1,280 |
| Lv5  | 4,200 | 2,520 | 1,680 |
| Lv6  | 5,400 | 3,240 | 2,160 |
| Lv7  | 6,400 | 3,840 | 2,560 |
| Lv8  | 8,000 | 4,800 | 3,200 |
| Lv9+ | 27,000 | 16,200 | 10,800 |

---

## Random Calls (per minute)

| | Coins/min |
|---|---|
| Caller pays | 600 |
| Receiver earns | 360 (60%) |
| Platform keeps | 240 (40%) |

These are product defaults. Backend env config owns the active random-call rate and split through `RANDOM_CALL_RATE_COINS_PER_MINUTE` and `RECEIVER_SHARE_BPS`.

---

## Reusable Gift Module

Gifts are a first-class reusable monetization primitive, not a live-only feature.

| Surface | Gift behavior |
|---|---|
| Inbox | Send a gift from a DM thread; message timeline shows the gift event |
| Normal live | Viewers send gifts during free live |
| Premium live | Viewers can pay the entry gift/sticker and continue sending gifts inside |
| Direct call | Caller can send gifts during paid 1:1 call |
| Random call | Caller can send gifts during paid random call |

Gift rules:

- No free emoji gifts. A gift is always a paid catalog item committed by the backend.
- One backend gift catalog and one mobile animation renderer are reused across all surfaces.
- The backend catalog is the pricing and availability source of truth. Each gift exposes `sectionId`, display name, coin cost, thumbnail URL, animation URL/type, animation tier, enabled state, and allowed surfaces. Flutter must not hardcode gift prices or surface eligibility.
- Backend validates balance, deducts coins, records the ledger transaction, credits host sparks/revenue, then emits/permits the visible gift event.
- `POST /v1/economy/gifts/send` is the reusable send contract. New callers send `surface`, `contextId`, `receiverUserId` when the surface needs one, `giftId`, `quantity`, and an idempotency key.
- Inbox gifts are backend-committable through the reusable contract: backend validates the receiver, derives/checks the canonical chat context from sender/receiver ids, rejects self-gifts and blocked pairs, locks the sender wallet, and writes the receipt in the same transaction.
- Inbox gift chat cards are backend/Admin-written Firestore projections after the ledger commit. Clients cannot create `type=gift` chat messages through Firestore rules; they can only read the card and update normal delivered/read receipts.
- Inbox and live-room gift projection delivery is tracked by `gift_delivery_outbox`, written in the same Postgres transaction as `gift_events`. A paid gift cannot commit without a durable delivery record for its visible Firestore/RTDB projection.
- Gift projection delivery is idempotent by `giftEventId`: inbox uses the Firestore message id, and live rooms use the RTDB gift event key. Retry delivery must not re-run the wallet ledger.
- Pending or failed gift projections can be retried through the protected internal backend delivery worker endpoint. Projection failure affects visible animation/card delivery only; wallet/revenue truth remains the committed Postgres ledger.
- Inbox gift cards show the server thumbnail/name/coin amount in the message timeline. If the recipient has not read the gift message, the thread auto-plays the gift animation once on open; the card remains durable for later review.
- Direct/random call gifts validate that the requested surface matches the actual call mode before charging.
- Gifts unavailable for a requested surface are rejected even when the gift id exists.
- Every committed gift has a durable `gift_events` receipt with a stable `giftEventId`, surface, context, sender, receiver, catalog price, quantity, split, sender balance after, delivery status, and timestamp.
- Visible gift events must reference the durable `giftEventId`; client-visible delivery is not money truth.
- Gift events are visible UX; wallet/revenue truth is always Postgres.
- Default split: host receives 60% value in sparks/revenue, platform keeps 40% before infrastructure and store economics are modeled. Backend currently uses `RECEIVER_SHARE_BPS` for the receiver share.
- Spark awards are calculated from integer receiver coins rather than floating-point USD multiplication.
- Gift assets are CDN-hosted Lottie/Rive/SVGA/animation payloads; 0 heavy gift animations ship in the app bundle. `GIFT_ASSET_BASE_URL` can point catalog URLs at the active CDN.

---

## Premium Live Rooms (paid group live)

Premium live is Zephyr's original monetized group mode: a host can convert a normal free live into a paid room.

| Mode | Many viewers? | Paid per minute? | Gifts? | Interruptible by direct/random call? |
|---|---:|---:|---:|---:|
| Normal live | yes | no | yes | yes |
| Premium live | yes | yes | yes | no |
| Random call | no | yes | yes | no |
| Direct call | no | yes | yes | no |

Premium live mechanics:

- Host starts a normal live first.
- Host can press an upgrade action to transition the room into premium live.
- Existing viewers see the stream locked and must send/pay an entry gift, such as a 200-coin car sticker, to enter.
- After entry, viewers are billed per minute while inside, for example 600 coins/min.
- Premium live entry fee and per-minute rate are set by the host within level-based limits.
- All premium live limits are backend-configured variables, not client hardcodes.
- Host earns a percentage of entry gifts, per-minute premium live billing, and gifts sent inside the room.
- Premium live is non-interruptible: direct call and random-call routing must skip the host while premium live is active.
- If a viewer balance is insufficient, backend ends that viewer's premium room session and the UI returns to the locked state or exits.
- RTDB owns realtime lock/unlock/audience/comment/reaction display; Postgres owns paid room sessions, billing ticks, entry payments, and revenue.

Premium live is not a replacement for direct/random calls. It fills the gap between free discovery live and private 1:1 monetization: many customers can pay modestly at the same time, while the host gets a stable earning mode.

---

## Leveling & Limits

Zephyr has two separate level systems. Do not mix them.

| Track | Who | Measures | Unlocks |
|---|---|---|---|
| Host Level | Hosts/creators | earning quality, completed paid minutes, gifts received, retention, trust, low reports | direct-call rate options, premium live pricing limits, premium viewer caps, discovery priority |
| Customer VIP Level | Customers/spenders | purchases, gifts sent, paid minutes, loyalty, account trust | profile frames, gift perks, coupons, support priority, cosmetic status |

The inspiration from apps like Tango is the shape, not the exact economy: loyalty/VIP systems reward purchases, gifts, and recurring monthly status, while creator levels should reflect earning power and platform trust. Zephyr's originality is that host earning level and customer VIP level are separate canonical tracks.

### Host Level

Host Level is the creator's earning/trust level. It should be earned by useful activity, not just account age.

Host XP inputs:

- Cleared sparks/revenue earned from direct calls, random calls, premium live, and gifts.
- Completed paid minutes with low dispute/report rate.
- Gifts received from unique customers.
- Free-live to paid conversion quality.
- Repeat customer/follower retention.
- Active hosting days.
- Manual verification and moderation trust.

Host XP exclusions/penalties:

- Refunded, charged back, or fraud-flagged purchases do not count.
- Sessions later marked abusive, fake, or policy-violating can remove XP.
- High report rate, bans, chargeback clusters, or moderation strikes can freeze level progression or demote caps.

Host Level controls configurable limits:

| Config key | Meaning |
|---|---|
| `canStartPremiumLiveDirectly` | Whether host can open premium live without first starting free live |
| `premiumEntryGiftCoinMin` / `premiumEntryGiftCoinMax` | Allowed entry gift/sticker range |
| `premiumRateCoinsPerMinuteMin` / `premiumRateCoinsPerMinuteMax` | Allowed premium live per-minute range |
| `premiumViewerCap` | Max paying viewers in premium live |
| `freeLiveViewerCap` | Max viewers in normal live |
| `directCallRateOptions` | Direct-call rate choices available to host |
| `randomMatchWeight` | Discovery/matchmaking boost for trusted high-level hosts |

Suggested policy:

- Early hosts can start free live and upgrade to premium live only after minimum room activity.
- Trusted mid-level hosts can start premium live directly with conservative limits.
- High-level verified hosts get higher entry/rate/viewer caps and stronger discovery.
- All limits live in backend config/database tables. Mobile reads allowed options from API and never hardcodes pricing.

### Customer VIP Level

Customer VIP Level is spender loyalty plus account trust. It should make customers feel recognized without letting them bypass safety rules.

VIP XP inputs:

- Settled in-app purchases.
- Gifts sent across inbox, live, premium live, direct calls, and random calls.
- Paid minutes consumed in direct/random/premium live.
- Recurring monthly activity.

VIP XP exclusions/penalties:

- Refunded or charged-back purchases remove VIP progress.
- Fraud, abusive behavior, or moderation actions can freeze VIP perks.
- VIP level never bypasses report/block/moderation systems.

VIP Level controls configurable perks:

| Config key | Meaning |
|---|---|
| `profileFrame` | Cosmetic frame/badge |
| `chatBadge` | Visible badge in inbox/live comments |
| `monthlyCoupons` | Optional coin/gift purchase coupon count |
| `freeGiftAllowance` | Optional reusable gift allowance |
| `supportPriority` | Support priority tier |
| `premiumRoomPerks` | Optional cosmetic/queue perks, never free unauthorized entry |

Suggested policy:

- Maintain both `rolling30dVipLevel` and `lifetimeVipRank`.
- Rolling VIP creates monthly motivation; lifetime rank preserves prestige.
- VIP progress is backend-calculated from cleared ledger data.
- VIP perks are configurable and can be A/B tested without client releases.

### Level Config Contract

Level rules are product variables. Store them server-side and expose them through API.

```json
{
  "schemaVersion": 1,
  "hostLevels": [
    {
      "level": 1,
      "canStartPremiumLiveDirectly": false,
      "premiumEntryGiftCoinMin": 0,
      "premiumEntryGiftCoinMax": 0,
      "premiumRateCoinsPerMinuteMin": 0,
      "premiumRateCoinsPerMinuteMax": 0,
      "premiumViewerCap": 0,
      "freeLiveViewerCap": 0,
      "directCallRateOptions": [],
      "randomMatchWeight": 1.0
    }
  ],
  "customerVipLevels": [
    {
      "level": 1,
      "rolling30dXpRequired": 0,
      "lifetimeXpRequired": 0,
      "perks": {
        "profileFrame": null,
        "chatBadge": null,
        "monthlyCoupons": 0,
        "freeGiftAllowance": 0,
        "supportPriority": "standard"
      }
    }
  ]
}
```

---

## Platform Economics (Calls Only — No Gifts)

> Worst-case estimate. Assumes 100% of user spend goes to random calls. Gifts are pure margin on top of this.

**Per $1.00 a user spends — full cost waterfall:**

| Deduction | Amount |
|---|---|
| User pays | $1.00 |
| − Apple / Google store cut (30%) | −$0.30 |
| − Host payout (60% of coins) | −$0.42 |
| **Gross profit** | **$0.28** |
| − Agora random call (~$0.008/min × ~9.2 min) | −$0.074 |
| **Net before fixed costs** | **~$0.206 per $1** |

**Monthly fixed infrastructure costs:**

| Service | Cost/month |
|---|---|
| Apple Developer Account | ~$8.25 |
| Google Play Developer | ~$0 (one-time $25, done) |
| Render API (Standard, no sleep) | $25.00 |
| Render PostgreSQL | $7.00 |
| Render Redis (when added) | $12.00 |
| Firebase (FCM + Auth) | $0.00 (free tier to ~50K MAU) |
| Domain / SSL | ~$1.25 |
| **Total fixed** | **~$53.50/month** |

**Net profit projection (random calls only, no gifts):**

| Monthly gross revenue | Variable net (20.6%) | − Fixed costs | **Monthly net profit** | Effective margin |
|---|---|---|---|---|
| $500 | $103 | −$53.50 | **$49.50** | 9.9% |
| $1,000 | $206 | −$53.50 | **$152.50** | 15.3% |
| $2,500 | $515 | −$53.50 | **$461.50** | 18.5% |
| $5,000 | $1,030 | −$53.50 | **$976.50** | 19.5% |
| $10,000 | $2,060 | −$53.50 | **$2,006.50** | 20.1% |

**Floor is ~20% net margin** at scale on calls alone. Gifts push this toward 28%.
Calls are the volume driver. Gifts are the profit driver.

---

## Video Infrastructure: Agora

Chosen for its proprietary UDP protocol that bypasses Gulf region (UAE, Saudi) WebRTC filtering — a hard requirement for our target market. Single SDK covers both calls and live streaming.

**Agora live streaming cost breakdown:**

| Scenario | Host | Viewers | Duration | Agora cost |
|---|---|---|---|---|
| Small stream | 1 | 10 | 1hr | ~$0.72 |
| Medium stream | 1 | 50 | 1hr | ~$3.12 |
| Large stream | 1 | 200 | 1hr | ~$11.52 |

> Free live audience is naturally self-limiting: users in a random call cannot simultaneously watch a free live stream. Random calls pull users out of passive watching into active paid calls. Premium live is different: it is already paid and non-interruptible.

**Live stream viewer cap (by host level):**

These are product default caps. Backend config/database owns the active values; mobile must not hardcode them.

| Host Level | Max Viewers | Agora cost (1hr, no gifts) |
|---|---|---|
| ≤Lv3 | 20 | ~$1.32 |
| Lv4–Lv5 | 50 | ~$3.12 |
| Lv6–Lv8 | 100 | ~$5.92 |
| Lv9+ | 200 | ~$11.52 |

Caps serve two purposes: protect the platform from costly zero-gift streams at low levels, and incentivise hosts to level up (more viewers = more gift potential = more earning). In practice, free-live viewer counts stay lower because random calls can pull users into paid calls; premium live uses paid entry/per-minute billing instead.

---

## Random Call Strategy

Random calls are priced cheap intentionally (600 coins/min = ~$0.11/min to caller). The goal is volume, not margin per call.

**Why random calls win at scale:**
- Low barrier to tap → high frequency of use
- Caller is always paying — no passive free-riders like live
- 1,000 users × 30 min/day = 30,000 call-minutes/day = about **$20K/month net before fixed costs** at the current default price/split, before gifts
- Margin is thin per call (~20%) but volume makes it the biggest revenue line

**Random call as a hook:**
- Caller meets someone interesting → wants to call them again → books a direct call (higher rate)
- Direct call rates are 3.5× to 45× higher than random → upsell path
- Random call is the entry drug; direct call and gifts are the monetisation

**Free Live → Random / Premium Live → Direct Call funnel:**
1. User watches a live stream (free, no cost to them)
2. User taps random call, or host upgrades the room to premium live
3. User pays 600 coins/min in random or premium live
4. User likes the host → books direct call (Lv6 = 5,400 coins/min)
5. During inbox/live/premium/calls, user sends gifts → highest margin reusable feature

---

## Call Types & Mechanics

### Random Call

| State | Coins | What happens |
|---|---|---|
| Searching | 0 | Algorithm finds match (priority: interruptible free-live hosts → idle hosts/users) |
| Connected | 600/min | Both parties in call, coins tick |
| Next tapped | 0 | Coins stop instantly, screen blurs, new match search begins |
| New match found | 600/min | Coins resume |
| Call ended | 0 | Call over, coins stop |

- Caller opts in by seeking; receiver gets a `RandomCallInviteRibbon` with accept/decline/timeout.
- Backend creates the random call session and writes an RTDB `event=matched` signal to `direct_calls/{receiverUserId}`.
- On accept: receiver enters shared `DirectCallScreen(mode=random)`; billing ticks only while both parties are in the call.
- On decline/timeout: backend random-call cleanup runs and caller is not charged for a connected call.
- If matched host is in free live: their availability moves to busy/random-call while the call owns the UX.
- If host is in premium live: skip; premium live is non-interruptible
- When random call ends: stream stays paused — host must manually resume (safety)
- "Next" is free — no coins charged during transition between randoms

### Direct Call (paid, receiver sets rate)

- Caller initiates from receiver's `ProfilePage` or chat thread.
- Client creates a backend call session first through `POST /v1/economy/calls/start`, then writes the ringing signal to Firebase RTDB at `/direct_calls/{receiverUserId}`.
- RTDB payload: `callerId`, `callerName`, `callerAvatarUrl`, `sessionId`, `status`, `ts`
- Receiver's `HomeScreen` listens on that RTDB path → shows `IncomingCallOverlay` (accept/decline)
- On accept: receiver writes `status=accepted`; both navigate to `DirectCallScreen` (Agora video); backend tick endpoints own billing
- On decline: caller is not charged, RTDB node cleaned up
- Rate is set by receiver based on their level (2,100 → 27,000 coins/min)
- Receiver earns 60% of the rate they set
- Camera-off detection: `onRemoteVideoStateChanged` with reason-based muting (not state-based) to avoid false positives on camera flip

---
