# Zephyr Agent Operating Manual

This is the single entry point for Codex and other coding agents in this repository. Zephyr is engineered through source-first work, official documentation, canonical source-of-truth gates, strict module ownership, clean object-oriented architecture, performance discipline, and proof before claims.

Keep this file lean. If it grows beyond 200 lines, move detail into the owning `docs/product/` file and keep only the operating rule here.

## 1. Start With Truth

Before every implementation, bug fix, review, audit, or docs change:

- read `docs/product/current-state.md`
- identify and read the task-specific owner docs
- read the owning code and tests
- check whether a module/component/service/adapter/helper/value object already exists
- state the task contract before editing

When a task touches a third-party system, official third-party documentation comes first. Always. This includes Firebase, Firestore, RTDB, FCM, Google Auth, Apple Auth, Apple IAP, Google Play Billing, Agora, Cloudinary, Render, Postgres hosting behavior, app store rules, and any SDK or external API. For Firebase work, classify the surface first: Auth, Firestore, Storage, RTDB, FCM, or Functions. If RTDB is in the read/write/listener path, read `docs/product/rtdb-contract.md`; if not, state RTDB is out of scope.

Do not rely on memory, old code, old comments, blog posts, or previous chat claims when official third-party behavior is relevant.

Task owner docs:

| Task touches | Read |
|---|---|
| Architecture, ownership, source of truth, realtime | `docs/product/architecture.md` |
| RTDB paths, fields, rules, listeners, realtime writes | `docs/product/rtdb-contract.md` |
| Commands, env, deploy, rollback, release operations | `docs/product/operations.md` |
| Paths, packages, DB notes, endpoints | `docs/product/code-reference.md` |
| Economy, pricing, gifts, premium live, compliance, calls | `docs/product/product-model.md` |
| Screens, navigation, states, interactions | `docs/product/roadmap-ui.md` |
| Latest release/change artifact | `docs/product/release-history.md` |
| Current quality grade or gap | `docs/product/audit-log.md` |

Never treat old TODOs, release history, previous chat claims, or stale assumptions as truth when they conflict with current code, tests, current-state, or architecture docs.

## 2. Task Contract Before Editing

Before editing, state the contract in concrete terms:

- behavior requested
- owning module
- canonical source of truth
- only allowed writer and allowed readers
- existing reusable module/component checked
- files likely to change
- automated tests/gates/performance checks to run
- manual smoke needed, if automation cannot prove it
- docs likely to change

If any answer is unclear, stop and inspect before editing. For bugs, add targeted logs/assertions/breakpoints at the owning boundary before changing behavior, then keep only useful guarded diagnostics. Do not code from vibes.

## 3. Source Of Truth Gate

Every durable behavior has one canonical owner.

The agent must know the canonical data owner, only allowed writer, allowed readers, projections/caches, security rule or backend guard, owning module, required automated test, and required smoke.

Projections, caches, UI state, compatibility fields, and old comments are not truth. They are disposable views of the canonical owner.

If the source of truth is unclear, stop. Do not implement until the owner is found or deliberately defined.

## 4. Module And OO Law

Everything in Zephyr is a module. This rule is not optional.

Each module is formed from reusable components, services, adapters, and value objects. Before creating anything new, reuse or improve the existing owner when one exists.

Do not duplicate behavior. Duplication means the module boundary is wrong.

Every new or changed module must have one responsibility, one public contract, one source of truth, explicit lifecycle ownership, clear error and performance behavior, protected invariants, and proof.

The code must follow advanced object-oriented architecture:

- encapsulation
- high cohesion
- low coupling
- composition over duplication
- explicit interfaces
- dependency inversion where boundaries need protection
- polymorphism where behavior varies by type
- clear ownership of state and lifecycle

No unwanted wiring is allowed. Screens, services, listeners, adapters, and helpers must connect through the owning module's public contract. If a change makes the code tangled, hidden, duplicated, or fragile, stop and fix the module boundary.

## 5. Verification Gate

No module, component, service, adapter, endpoint, rule, or helper can be trusted without correctness and performance proof.

Before reuse, check that existing code satisfies the intended contract. After implementation, test the changed module and the regression path around it.

Core gates:

- Full regression gate: `pnpm check`
- Backend and realtime gate: `pnpm check:backend`
- Mobile gate: `pnpm check:mobile`
- Firebase rules gate: `pnpm check:realtime`
- Postgres race/idempotency gate: `pnpm check:db:race`
- Backend unit tests: `pnpm --filter zephyr-api test`
- Backend e2e tests: `pnpm --filter zephyr-api test:e2e`
- Backend build: `pnpm --filter zephyr-api build`
- Flutter analyze/tests: `cd apps/zephyr-mobile && flutter analyze && flutter test`

Default proof:
- unit test for every module or component that contains logic
- dedicated rule/emulator test for every Firebase, Firestore, RTDB, or Storage path, field, listener, write contract, or permission change
- backend test for API, database, economy, session, push, or projection behavior
- Flutter test for UI state, navigation, lifecycle, or client module behavior
- Flutter UI changes must be adaptive across iOS phone, Android phone, iPad, and Android tablet: use standard Flutter constraints/insets, avoid phone-only fixed layout assumptions, protect text/keyboard/notch/nav overflow, and state any unsmoked surface as unproven
- manual smoke or profiling when real devices, third-party SDKs, payments, push, calls, live video, performance, or lifecycle transitions cannot be proven by automation

Run the smallest useful gate while iterating. Run broader gates when the change touches shared contracts, auth/session, realtime, economy, navigation, Firebase rules, release behavior, or cross-module boundaries.

Do not call code reusable, fixed, done, top-tier, A+, or production-ready until its contract is proven. If proof is incomplete, state the gap.

## 6. Hard Architecture Rules

- No guest login. Google and Apple only.
- No Socket.IO, WebSocket runtime, or new socket dependency.
- No presence polling. Use RTDB listeners. Live-room heartbeat is only room liveness.
- No new Firebase or RTDB singleton. Use `FirebaseChatService.instance` or module facades behind it.
- RTDB contracts are mission-critical. Every new RTDB path, field, listener, or write must have an owning module, security rule coverage, targeted tests, and adjacent regression checks before reuse.
- No client-owned economy writes. Wallet, gifts, calls, IAP, refunds, and revenue are backend/Postgres-owned.
- No client-forged trusted realtime events. Backend/Admin fan-out is required for trusted gift/session events.
- No duplicate identity source. User identity lives in RTDB `profiles/{userId}`.
- No duplicate presence source. Availability lives in RTDB `presence/{userId}` and backend projections.

## 7. Stop The Line

Stop and fix, contain, or ask before continuing when:

- a required automated gate fails
- a manual smoke step fails
- docs and code disagree on source of truth, commands, env vars, routes, rules, schema, version, or ownership
- source of truth cannot be identified
- a change would make the client trusted for money, sessions, gifts, IAP, refunds, moderation, or trusted realtime fan-out
- Firebase rules changed without matching emulator coverage
- a shared model, DTO, route, listener, lifecycle hook, transaction, or Firebase path changed without adjacent-contract review
- a fix needs scattered defensive conditionals instead of a change in the owning module
- a regression or performance degradation appears in any previously working path
- a deploy, release, schema migration, production Firebase rules deploy, version bump, or dependency addition is needed but was not explicitly requested

For repeated regressions, production incidents, failed deploys, failed releases, payment/IAP issues, or cross-module failures, use the A3 record in `docs/product/operations.md`.

## 8. Ask First

Ask before changing architecture ownership, adding a production dependency, changing database schema/migrations, changing production Firebase rules, changing release version/build numbers, deploying to Render/Firebase, deleting user/runtime data, running destructive git commands, reverting user changes you did not make, or doing broad refactors unrelated to the task.

## 9. Definition Of Done

A task is done only when:

- requested behavior is implemented
- owning module contract is clear
- relevant automated checks pass, or failures are reported with exact command output
- required manual smoke is completed or listed as remaining
- adjacent module regression and performance risk was considered
- unrelated files were not changed
- documentation gate is complete
- final response states what changed, what was verified, and what risk remains

## 10. Context Rot Audit

Audit this file when an agent repeats the same mistake twice, after any major architecture change, after command/tooling changes, and at least monthly.

The audit must remove stale rules, verify commands still run, verify doc ownership still matches reality, keep this file under 200 lines, and move detailed reference material into `docs/product/`.

## 11. Enforcement Ladder

Prose is the weakest control. When a rule can be enforced mechanically, prefer:

- type system, schema, validator, or database constraint
- unit/integration/rules test
- linter, formatter, pre-commit hook, CI gate, or Codex rule/hook
- small reusable module API that makes wrong usage hard

If a workflow becomes detailed or repeated, move it into `docs/product/`, a skill, MCP-backed workflow, automation, or focused subagent instead of bloating this file.

## Final Rule. Update The Truth

The last step of every task is documentation alignment.

Anything we do can change truth: code, tests, config, assets, release/build work, deploy work, schema, dependencies, product behavior, or docs.

After the work, update the correct document or explicitly say `Docs: no product truth changed`.

Owning docs:

- `docs/product/current-state.md`: blockers, current state, launch readiness, active TODOs, immediate next work
- `docs/product/architecture.md`: source of truth, module ownership, hard rules, realtime contracts
- `docs/product/rtdb-contract.md`: RTDB paths, fields, writers, readers, rules, listeners, tests
- `docs/product/operations.md`: commands, env vars, deploy, rollback, release operations, smoke tests
- `docs/product/code-reference.md`: paths, packages, DB notes, endpoints, code structure
- `docs/product/product-model.md`: economy, pricing, gifts, premium live, compliance, call mechanics
- `docs/product/roadmap-ui.md`: screen contracts, navigation, states, interactions
- `docs/product/release-history.md`: latest release/change artifact only
- `docs/product/audit-log.md`: current quality grade or quality gap

For docs-only edits, still check whether another doc now needs alignment.

No task is finished until docs match the reality created by the task.
