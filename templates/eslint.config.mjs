import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const GENAI_SDK_MESSAGE =
  "Use runTask() from @/lib/llm/router instead. Direct SDK calls bypass cost recording (the llmCalls subcollection), fallback routing, and the prompt-version invariant. New providers belong under lib/llm/providers/. The audio transcription helper at lib/transcribe/gemini-audio.ts is the one sanctioned exception (Files API doesn't fit the runTask contract). See .claude/rules/llm-pipeline.md.";

const ADMIN_SDK_MESSAGE =
  "Don't import @/lib/firebase/admin directly. Route handlers, server actions, server components, and email helpers must go through @/lib/firebase/repos (typed helpers, Sentry-instrumented choke points). For auth-domain calls (verifyIdToken, verifySessionCookie, createSessionCookie) use @/lib/auth/session. Direct admin access is allow-listed only for lib/firebase/, lib/auth/, and lib/pipeline/. See .claude/rules/firestore.md.";

const STRIPE_SDK_MESSAGE =
  "Direct stripe SDK imports must go through lib/billing/ (the stripe-client singleton + webhook-handlers + entitlements live there). Route handlers can import from @/lib/billing/* without touching the SDK directly. See .claude/rules/billing.md.";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,

  // Architectural import gate:
  //   - @google/genai is restricted everywhere except its owning modules
  //     (lib/llm/providers/ and lib/transcribe/).
  //   - @/lib/firebase/admin (and any relative path ending in
  //     `/firebase/admin`) is restricted everywhere except lib/firebase/
  //     (owns the bootstrap), lib/auth/ (verifyIdToken / session cookies),
  //     and lib/pipeline/ (server orchestration). PR #41 review caught a
  //     direct-adminDb write in lib/email/send-daily.ts that this rule
  //     would have stopped; the AGENTS.md "Enforced by ESLint" claim
  //     points at this block.
  //   - stripe SDK is restricted everywhere except its owning modules
  //     (lib/billing/), the stripe route handlers (app/api/stripe/), and
  //     the manual validation harness (scripts/). Keeps the stripe-client
  //     singleton + webhook-handlers + entitlements as the only path
  //     other server code uses to reach Stripe.
  {
    files: ["**/*.{ts,tsx,mts,cts}"],
    rules: {
      "no-restricted-imports": [
        "error",
        {
          paths: [
            { name: "@google/genai", message: GENAI_SDK_MESSAGE },
            { name: "@/lib/firebase/admin", message: ADMIN_SDK_MESSAGE },
            { name: "stripe", message: STRIPE_SDK_MESSAGE },
          ],
          patterns: [
            { group: ["**/firebase/admin"], message: ADMIN_SDK_MESSAGE },
          ],
        },
      ],
    },
  },
  {
    files: [
      "lib/llm/providers/**/*.{ts,tsx,mts,cts}",
      "lib/transcribe/**/*.{ts,tsx,mts,cts}",
      "lib/firebase/**/*.{ts,tsx,mts,cts}",
      "lib/auth/**/*.{ts,tsx,mts,cts}",
      "lib/pipeline/**/*.{ts,tsx,mts,cts}",
    ],
    rules: { "no-restricted-imports": "off" },
  },
  // Stripe-only allow-list: re-states the rule WITHOUT the stripe entry so
  // these dirs can import the SDK directly while genai + admin SDK gates
  // remain in force (defense-in-depth — none of these dirs need either,
  // but if a future edit reaches for adminDb from a billing handler the
  // rule should still bite).
  {
    files: [
      "lib/billing/**/*.{ts,tsx,mts,cts}",
      "app/api/stripe/**/*.{ts,tsx,mts,cts}",
      "scripts/**/*.{ts,tsx,mts,cts}",
    ],
    rules: {
      "no-restricted-imports": [
        "error",
        {
          paths: [
            { name: "@google/genai", message: GENAI_SDK_MESSAGE },
            { name: "@/lib/firebase/admin", message: ADMIN_SDK_MESSAGE },
          ],
          patterns: [
            { group: ["**/firebase/admin"], message: ADMIN_SDK_MESSAGE },
          ],
        },
      ],
    },
  },

  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
    // Compiled Cloud Function bundle and its workspace node_modules:
    "functions/lib/**",
    "functions/node_modules/**",
  ]),
]);

export default eslintConfig;
