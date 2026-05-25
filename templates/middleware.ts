import { NextResponse, type NextRequest } from "next/server";
import { applySecurityHeaders } from "@/lib/security/headers";

// Lightweight presence check only — actual session verification happens in
// server components / route handlers via lib/auth/session.getCurrentUser().
// (firebase-admin doesn't run in the Edge runtime, and Next.js 16's `proxy`
// alternative would force a Node runtime cold-start on every request — overkill
// for a redirect rule.)
//
// Security response headers (CSP, HSTS, X-Frame-Options, Referrer-Policy,
// Permissions-Policy, X-Content-Type-Options) are attached here via
// applySecurityHeaders() on BOTH the protected-redirect path and the
// pass-through path. See lib/security/headers.ts.

// Routes inside the (app) authenticated group. Mirrors the page tree under
// app/(app)/ so the Edge presence-check redirects unauthed users on the
// fast path. The (app) layout's getCurrentUser() is still the real verifier
// — this is just an optimization. Keep this list in sync with app/(app)/.
const PROTECTED_PREFIXES = [
  "/today",
  "/history",         // was /archive — rescoped 2026-05-21
  "/channels",
  "/analyses",
  "/action-items",
  "/search",
  "/settings",
  "/admin",
];

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  const isProtected = PROTECTED_PREFIXES.some(
    (p) => pathname === p || pathname.startsWith(`${p}/`)
  );

  if (isProtected) {
    const cookie = req.cookies.get("__session")?.value;
    if (!cookie) {
      const url = req.nextUrl.clone();
      url.pathname = "/sign-in";
      url.searchParams.set("next", pathname);
      const res = NextResponse.redirect(url);
      applySecurityHeaders(res.headers);
      return res;
    }
  }

  const res = NextResponse.next();
  applySecurityHeaders(res.headers);
  return res;
}

// Run on every request EXCEPT static assets + Next.js internals, so
// security headers (CSP, HSTS, etc.) attach to public routes (/, /sign-in,
// /pricing, /unsubscribe) and API routes too — not just the authenticated
// `(app)` group. The `isProtected` check inside the handler still gates
// the auth-redirect to only PROTECTED_PREFIXES.
export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|icon|apple-icon|manifest|sitemap.xml|robots.txt).*)",
  ],
};
