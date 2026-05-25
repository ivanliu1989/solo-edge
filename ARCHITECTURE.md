# ARCHITECTURE — TEMPLATE

This is the document that explains HOW the parts fit together. AGENTS.md tells you WHAT the parts are; ARCHITECTURE.md tells you WHY they're shaped that way and how data flows between them.

A new AI session should be able to read this in 5 minutes and reason correctly about:
- Where to add a new feature
- What the trust boundary is between client and server
- How auth state propagates
- How costs are tracked
- What the dependency direction is between layers

## The stack at a glance

ONE PARAGRAPH stating the chosen frameworks + their version pin. Example:

> Next.js 16.2.6 (App Router, Server Components by default) on Firebase App Hosting. Firebase Auth (email/password + Google) for sign-in, session-cookie pattern for server reads, Firestore (named DB, not default) for state, Cloud Functions Gen 2 for the async pipeline, Google Gemini 3.x via `@google/genai` as the task-routed LLM layer.

## The data flow (request → response)

A diagram or numbered walkthrough of a typical authenticated request. Example flow for a paste-analyze action:

```
1. Browser: POST /api/analyze { url }                   client → server
2. middleware.ts:                                       edge runtime
   - Read __session cookie (presence check only)
   - 401 redirect if missing → /sign-in
3. app/api/analyze/route.ts:                            node runtime
   - getCurrentUser() verifies session cookie via firebase-admin
   - checkRateLimit({ uid, bucket: "analyze", limit: 10 })
   - Zod-validate body
   - createOrGetAnalysis(uid, videoId, promptVersion) writes Firestore doc at status="queued"
4. Cloud Function (functions/src/index.ts):             gen 2 trigger
   - analyzeVideoOnCreate fires on the new doc
   - Calls lib/pipeline/analyze-video.ts runAnalysis()
   - runAnalysis transitions: queued → fetching_metadata → transcribing → extracting → synthesizing → critiquing → done|failed
   - Each LLM call goes through lib/llm/router.ts (cost capture + Zod validation)
5. Browser: Firestore onSnapshot subscription:          client SDK
   - Streams status updates in real-time to AnalysisDetailLive
   - Renders status pill + insights as they land
```

## The auth handshake

How does a user become authenticated? Be exhaustive about every transition.

```
1. SignInForm.tsx (client):
   - signInWithEmailAndPassword OR signInWithPopup(GoogleAuthProvider)
   - cred.user.getIdToken(true) → fresh JWT
2. POST /api/auth/session { idToken, timezone? }:
   - adminAuth.verifyIdToken(idToken)
   - ensureUserDoc(uid, email, timezone)
   - adminAuth.createSessionCookie(idToken, expiresIn: 7d)
   - res.cookies.set("__session", cookie, { httpOnly, sameSite: lax, secure })
3. router.refresh() → next request includes __session cookie
4. Server Components call getCurrentUser():
   - cookies().get("__session")
   - adminAuth.verifySessionCookie(cookie, /*checkRevoked=*/true)
   - returns { uid, email } or null
```

## The dependency direction (load-bearing)

Layers can only import "downward." If you find an upward import, it's a bug.

```
app/         (Server Components, route handlers, layouts)
  ↓ imports from
components/  (UI, Client + Server)
  ↓ imports from
lib/         (auth, firebase, llm, billing, security, format, history)
  ↓ imports from
node_modules
```

`lib/firebase/admin.ts` and `lib/firebase/repos.ts` are server-only. ESLint blocks `@/lib/firebase/admin` imports outside `lib/firebase/`. The session cookie is the only auth contract between client and server — never pass uid as a route param.

## How costs are tracked (if you use LLMs)

`lib/llm/router.ts` is the choke point. Every `runTask()` call writes an `llmCalls` row + atomically increments the parent doc's `costCents` field via `FieldValue.increment`. The same daily cap is enforced TWICE: at the API boundary (`/api/analyze` route layer) AND inside `runAnalysis` (pipeline-layer rail) — so a Cloud Function trigger discovered via channel polling can't bypass the route gate.

## How entropy is defended

See [docs/10-entropy-defense.md](docs/10-entropy-defense.md). The summary:

- ESLint `no-restricted-imports` enforces the chokepoints (LLM router, Stripe client, Firebase Admin).
- `scripts/check-docs-updated.sh` fails CI when behavior-bearing source files change without matching docs.
- `scripts/check-doc-content-drift.sh` fails CI when docs reference symbols that don't exist (backticked-name typos) or carry stale prose.
- `scripts/check-e2e-coverage.sh` fails CI when Pro-gated user flows don't have a Playwright spec.
- `lib/firebase/index-manifest.test.ts` asserts every composite Firestore index in `firestore.indexes.json` has a code consumer (and vice versa).
- `QUALITY_SCORE.md` carries the running session-quality log so the same entropy doesn't get re-caught next quarter.

## What to update when

If you change... | You must also update...
--- | ---
`lib/firebase/types.ts` (doc shape) | Every consumer; this is the contract
`lib/firebase/repos.ts` (write helper) | The matching rule in `.claude/rules/firestore.md`
`lib/llm/router.ts` or task routing | `.claude/rules/llm-pipeline.md`
`middleware.ts` (auth or headers) | `.claude/rules/auth.md`
Stripe webhook handlers | `.claude/rules/billing.md`
A `(app)/*/page.tsx` route's behavior | `AGENTS.md` Key Directories OR a doc — CI gate enforces

## The non-obvious decisions

Each one closes a documented failure mode. Briefly: why we did it this way and what would break if we didn't.

(Fill in for your stack. Examples from leapedge-clip:)

- **Named Firestore database, not `(default)`.** Lets you have separate dbs for separate apps under one Firebase project. Without this, two products share the same indexes namespace.
- **Cookie name is `__session`.** Firebase Hosting strips most cookies on cached responses; `__session` is on the allowlist.
- **All Firestore reads/writes go through `repos.ts`.** Makes the API surface auditable: search "repos.ts" + grep for the function name gives you every caller.
- **Cost cap fires TWICE.** Once at the route layer, once in the pipeline. The pipeline rail catches Cloud Function-discovered work that bypasses the route.
- **Webhook idempotency is `lastWebhookAt`-based, stamped from Stripe's `event.created`, not server time.** Out-of-order Stripe events would otherwise overwrite a fresher state with a stale one.
