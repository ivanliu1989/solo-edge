# E2E Coverage Rules

Pro-gated user flows MUST have a Playwright e2e spec under `e2e/`. The required list is enforced mechanically by `scripts/check-e2e-coverage.sh` in CI — a missing spec fails the PR.

- **Framework is Playwright (full-browser e2e), not React Testing Library.** Component-level unit tests were considered and rejected in favor of fewer, higher-value e2e specs that prove the gated experience end-to-end. Don't add a `*.test.tsx` for a UI component unless it tests a pure helper — push behaviour assertions into the e2e suite.
- **Required spec inventory is hardcoded in `scripts/check-e2e-coverage.sh`.** When you add a gated user surface:
  1. Decide the spec filename (`e2e/<surface>.spec.ts`)
  2. Add it to the REQUIRED array in `check-e2e-coverage.sh`
  3. Commit the spec file alongside the source change
  Skip the script edit and the surface ships without coverage.
- **Running tests is currently local-only.** CI runs `scripts/check-e2e-coverage.sh` as a presence-check — it does NOT execute the suite (would require browser install + dev server). Locally: `pnpm dev` in one terminal, then `pnpm dlx playwright install chromium` once and `pnpm test:e2e` thereafter.
- **Auth helper lives at `e2e/helpers/auth.ts`.** `signInAs({ context, tier })` mints a Firebase custom token via `firebase-admin`, exchanges for ID token via Auth REST `signInWithCustomToken`, then POSTs to the app's own `POST /api/auth/session` for a real `__session` cookie — no app-side test-only code path. Companion `e2e/helpers/firestore-seed.ts` pre-seeds tier fields on the user doc — overrides the `ensureUserDoc` default for specs that need to exercise paid-tier branches. Auto-emulator-aware via `FIREBASE_AUTH_EMULATOR_HOST`.
- **Spec conventions:** import from `@playwright/test`, name file after the gated surface, use `page.goto("/<route>")` against `baseURL` from config, prefer accessible-name locators (`page.getByRole("heading", { name: /pricing/i })`) over CSS selectors, assert visible text + critical CTA presence rather than DOM structure.
- **Remediation:** if `check-e2e-coverage.sh` fails on your PR, add the missing spec to `e2e/` using the exact filename from the failure output. Required list is small + finite; no separate manifest.
- **Escape hatch:** `[skip e2e]` in the commit message — only for emergency hotfixes that can't wait for a new spec.
- **Spec files with `test.skip(...)` only count as "present."** Useful for stubbing in a new gate while writing the implementation. The spec file existing is the contract.
