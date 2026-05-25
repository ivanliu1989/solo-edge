# 08 — LLM pipeline patterns

The task-routed, version-stamped, cost-audited pipeline. Distilled from leapedge-clip's three-stage analysis flow.

## The architecture

```
runTask()  ──►  taskRouting  ──►  Provider (Gemini/OpenAI/Anthropic)
   │                                       │
   │                                       └──► retry on 429/5xx
   │                                            with RetryInfo.retryDelay
   │
   ├──► withGeminiRetry  ──► 3 attempts, exp backoff, max 60s
   │
   ├──► Zod schema validation  ──► structured output enforced
   │
   └──► recordLlmCall  ──► writes llmCalls row + increments parent doc costCents
```

## The router monopoly

`lib/llm/router.ts` is the only place that calls a provider SDK. ESLint enforces:

```javascript
// eslint.config.mjs
{
  files: ["**/*.ts"],
  ignores: ["lib/llm/providers/**", "lib/transcribe/**"],
  rules: {
    "no-restricted-imports": ["error", {
      paths: [{ name: "@google/genai", message: "Import via lib/llm/router" }],
    }],
  },
}
```

The `lib/transcribe/` exception exists because audio transcription uses Gemini's Files API (multimodal input), which doesn't fit `runTask`'s text-in/structured-out contract.

## Prompt versioning

```
lib/llm/prompts/{task}/v{n}.ts
  └─ exports: version, system, buildUser, schema, schemaName, schemaDescription
```

Editing a shipped prompt requires a new `v{n+1}` file. The composite `ANALYSIS_PROMPT_VERSION` (e.g. `${KEYPOINTS_PROMPT_VERSION}-${INSIGHTS_PROMPT_VERSION}`) becomes part of the Firestore doc ID via `analysisDocId(videoId, version)`.

Bumping a prompt without bumping `n` overwrites the prior analysis at the same ID — silent data loss. The naming convention catches this at code review.

**Separator is `-` (URL-safe ASCII), never `+`.** `+` gets URL-decoded as a space by some routing layers and breaks `/analyses/[id]`.

## Task routing

```typescript
// lib/llm/router.ts
const taskRouting: Record<Task, { primary: ModelChoice; fallback?: ModelChoice }> = {
  keypoints: { primary: "gemini-3.1-flash-lite" },
  insights: { primary: "gemini-3.5-flash" },
  daily_report: { primary: "gemini-3.5-flash" },
  critique: { primary: "gemini-3.1-flash-lite" },
  email_digest: { primary: "gemini-3.1-flash-lite" },
};
```

Flash-tier for cheap structured tasks. Pro-tier for reasoning-heavy synthesis. Update the table when a new model lands — single source of truth.

`fallback` is supported in the router but not used in production. Cross-model redundancy adds cost and complicates cost accounting. Skip until you actually need it.

## Output schemas are Zod

```typescript
export const InsightsSchema = z.object({
  insights: z.array(z.object({
    ticker: z.string().nullable(),
    direction: z.enum(["long", "short", "neutral", "avoid"]),
    conviction: z.enum(["low", "medium", "high"]),
    thesis: z.string(),
    supportingQuote: z.string(),
  })),
});

const result = await runTask("insights", { system, user, schema: InsightsSchema });
// result is parsed, typed InsightsSchema output
```

The Gemini provider passes `z.toJSONSchema(schema)` as `responseJsonSchema`, then re-parses with the original Zod schema for runtime validation.

## Transient retry

`withGeminiRetry` in `lib/llm/retry.ts`. Retryable codes: **429, 500, 503, 504**. Defaults: 3 attempts, exponential backoff `1s/2s/4s` ±20% jitter, max `60s` per delay.

When the SDK error payload carries `RetryInfo.retryDelay` (Google's quota hint, e.g. `"35s"`), the helper honors it instead of default backoff. Clamped to `[baseDelayMs, maxRetryAfterMs]`.

**Non-retryable** (throws on first attempt):
- 4xx other than 429 (auth, malformed request)
- Zod validation failures (re-asking returns the same parse failure)
- `RECITATION` blocks (defensive substring check; re-asking returns the same flag)

Worst case per call: 3 × 60s = 180s. Comfortably inside a 540s Cloud Function timeout.

## Cost capture

Every `runTask()` writes an `llmCalls` row + atomically increments the parent doc's `costCents` via `FieldValue.increment(call.costCents)` in a single `db.batch()`. Load-bearing for the per-user cost cap — a pipeline that fails midway still has honest cost reflected.

Pricing math lives in `lib/llm/pricing.ts` per model:

```typescript
const PRICING: Record<Model, { inputPerMillion: number; outputPerMillion: number }> = {
  "gemini-3.5-flash": { inputPerMillion: 0.30, outputPerMillion: 2.50 },
  // ...
};
```

`finalizeAnalysis` later overwrites `analyses.costCents` with the in-process tracked total as a reconciliation step.

## Per-tier daily cost cap

Entitlement carries `dailyCostCapCents` (Free 100¢ / Pro 300¢ / Max 1000¢). Both gates — route-layer (`/api/analyze`) and in-pipeline (`runAnalysis`) — read it via `getUserEntitlement({plan, subscriptionStatus})`. `past_due` dunning downgrade applies automatically.

Customer-facing message: `"Today's processing limit reached. Resets at local midnight."` (no dollar figures; raw cents stay in the Sentry payload).

## The no-throw rule (Cloud Functions)

```typescript
export async function runAnalysis(args: RunAnalysisArgs): Promise<void> {
  try {
    // ... pipeline stages
  } catch (err) {
    captureException(err, { site: "runAnalysis", uid, analysisId });
    await setAnalysisStatus({
      uid, analysisId,
      status: "failed",
      statusError: toUserStatusError(err),
    });
    // No re-throw. Returning is the contract.
  }
}
```

Throwing would race with Cloud Functions Gen 2's automatic retry semantics — could leave the doc in a weird state, double-bill, or double-process.

**The corollary:** any pipeline catch that doesn't re-throw MUST `captureException(err, { site, ...context })` first. Without it, failures stay invisible to Sentry.

## Caption-then-audio fallback (if your LLM input comes from YouTube)

```
transcribing stage:
  1. Try fetchCaptions(videoId) — 3-library chain (youtubei, youtube-transcript, youtube-captions-scraper)
  2. If ALL three throw or return 0 segments:
     transcribeYouTubeUrlWithGemini({ youtubeVideoId })
     → Passes the watch URL to Gemini's Files API as fileData.fileUri
     → Gemini fetches the video server-side, returns transcript
     → No local audio download needed
  3. Cache transcript with source: "youtube_captions" or "gemini_audio"
```

Audio path bypasses Cloud Run's YouTube bot detection. Gemini fetches from Google's infrastructure, which has different IP reputation than your Cloud Function's egress.

## Cross-user output cache

If your LLM output is deterministic given `(input, promptVersion)`, share it across users. Pattern:

```
analysisOutputs/{analysisDocId}  ← top-level shared cache
  └─ schema: { videoId, promptVersion, snapshot, hitCount, lastHitAt }
  └─ written on terminal status (done or failed)

users/{uid}/analyses/{analysisDocId}  ← per-user mirror
  └─ schema: { ...snapshot, costCents: 0 on cache hit }
```

Two-level check:
- **Level 1** at API boundary (`createOrGetAnalysis`) — if no per-user doc and shared cache has done, pre-populate user doc at status="done"
- **Level 2** at pipeline entry (`runAnalysis`) — catches the race where another user populated the cache between Level 1 and pipeline entry

Cache hits write `costCents: 0` to the per-user doc so the requester's accumulator isn't double-charged.

**Invariant** (load-bearing): no user-specific data may flow into LLM prompts. Adding personalization corrupts the cache for every other user. If personalization becomes necessary, split into cached-shared half + per-user delta applied post-cache-read.

## Friendly error wrapping

`lib/llm/status-error.ts`:

```typescript
export function toUserStatusError(err: unknown): string {
  const msg = err instanceof Error ? err.message : String(err);

  // Passthrough for messages we authored
  for (const pattern of FRIENDLY_PASSTHROUGH_PATTERNS) {
    if (pattern.test(msg)) return msg;
  }

  // Wrap known categories
  if (msg.includes("MAX_TOKENS") || msg.includes("429")) {
    return "Hit a transient issue. Please try again in a few minutes.";
  }
  if (err instanceof CaptionsUnavailableError) {
    return "Couldn't fetch a transcript for this video. Try again later.";
  }

  return "Failed unexpectedly. Please try again.";
}
```

The raw error stays on the Sentry capture for triage. The user sees a friendly category.

## Common mistakes

❌ **Calling `client.models.generateContent()` directly outside the router.** Bypasses cost capture, validation, retry. ESLint catches it.

❌ **Editing a shipped prompt without bumping `n`.** Silent overwrite of cached analyses at the same ID.

❌ **Throwing from `runAnalysis`.** Races with GCF retry. Always catch + write status="failed".

❌ **Catching without `captureException`.** Failures invisible to Sentry. The no-throw rule makes this especially load-bearing.

❌ **Adding personalization to a cached prompt.** Cache corruption for every other user.

❌ **Trying to bypass the daily cost cap "just this once."** The cap is the runtime safety net for cost. Bypassing it is the failure mode that causes the bill spike.

---

Read next: [09-observability.md](09-observability.md)
