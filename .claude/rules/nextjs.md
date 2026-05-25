# Next.js 16 Rules

This is Next.js 16 — the API surface differs from 14/15. Read `node_modules/next/dist/docs/` before writing new patterns.

- **`params`, `searchParams`, `cookies()`, `headers()`, `draftMode()` are async.** Page/layout signatures take `params: Promise<{ id: string }>`. `await` them.
- **Middleware runs on the Edge runtime.** `firebase-admin` cannot run there. `middleware.ts` is presence-only — checks for `__session` cookie, redirects to `/sign-in`. Real verification is `getCurrentUser()` in Server Components.
- **Don't migrate `middleware.ts` → `proxy.ts` casually.** Next.js 16's codemod offers it; for this stack the Edge presence-check is correct as middleware. Switching to `proxy.ts` (Node runtime) forces a Node cold-start on every request.
- **Server Components by default.** Add `"use client"` only when the file uses hooks, browser APIs, or event handlers. Never import server-only modules from a client component — `import "server-only"` enforces it.
- **Route groups in parentheses don't affect URLs.** `app/(app)/today/` serves `/today`. `(app)` is the authenticated group; its `layout.tsx` re-checks the user.
- **Two distinct route groups: `(app)` vs `(admin)`.** `(app)` for users (its layout calls `getCurrentUser()`, redirects to `/sign-in`); `(admin)` for ops (its layout calls `requireAdmin()`, `notFound()`s non-admins to avoid enumeration).
- **Route handlers in `app/api/<path>/route.ts`** with named exports (`GET`, `POST`, `DELETE`).
- **Webhook routes MUST use `req.text()` for raw body, never `req.json()`.** HMAC verification hashes unparsed bytes.
- **Public pages live at root of `app/`** (no route group). Force-dynamic: `export const dynamic = "force-dynamic"`. Required because the header CTA reflects auth state via cookies.
- **Stream page chrome via `<Suspense>` around an inner async Server Component** when the page has fast shell + slow data. Shell (auth check, header, ActiveRunsStrip, paste form) renders + flushes immediately; inner component runs `Promise.all` reads and streams in.
- **`notFound()` works inside inner async Server Components** — throws `NEXT_HTTP_ERROR_FALLBACK;404` which unwinds the route segment. The inner component MUST stay a Server Component or Suspense streaming silently degrades.
- **Auth check pattern:** `const user = await getCurrentUser(); if (!user) redirect("/sign-in")`. Never duplicate in middleware.
- **Use `next/link` for in-app, `next/image` for images.** Don't hand-roll `<a href>` for internal routes.
- **No `getServerSideProps` / `getStaticProps` / `pages/api/`.** Data fetching in async Server Components.
- **Server actions in `app/<route>/actions.ts`** with `"use server"` file directive. Shape: auth check → read FormData → mutate via repos → catch with captureException → redirect with `?saved=X` or `?error=Y`. Never return a body — `Promise<void>`. Test by mocking `next/navigation.redirect` to throw.
- **Strip Timestamps before crossing server→client boundary.** Firestore `Timestamp` doesn't survive React's serializer. Map `.toDate().toISOString()` (or strip the field entirely if the client doesn't need it).
