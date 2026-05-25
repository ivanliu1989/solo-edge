// Security response headers. Applied by middleware on every response
// (no body — Edge runtime safe; firebase-admin is NOT used here).
//
// CSP is intentionally strict-but-realistic. Connecting in:
//   - Firebase Auth (apis.google.com for the GAPI loader,
//     securetoken.googleapis.com for session-cookie exchange,
//     identitytoolkit.googleapis.com for the REST API,
//     oauth2.googleapis.com for the Google sign-in token exchange).
//     Note: accounts.google.com is NOT in any directive — Firebase
//     Auth's signInWithPopup loads it in a popup window which has
//     its own CSP context, so the parent page's directive doesn't
//     gate it. A future switch to redirect-based Google sign-in OR
//     adding a Google Identity Services button would require adding
//     accounts.google.com to script-src + form-action.
//   - Firestore client SDK (firestore.googleapis.com)
//   - GA4 (googletagmanager.com, google-analytics.com)
//   - Stripe.js (js.stripe.com, api.stripe.com) — currently UNUSED
//     (Checkout is redirect-based) but pre-allowed so a future
//     embedded Elements integration doesn't require a CSP change.
//   - Sentry (sentry.io endpoints) — optional; allow but don't require.
//
// TODO(security): the current script-src is XSS-shape, not a meaningful
// XSS rail. 'unsafe-inline' + 'unsafe-eval' is required for Next.js's
// inline bootstrap script — nonce-based CSP would close the gap but
// requires Next.js runtime support that isn't current as of 16.2.6.
// Track upstream: Next.js issue tracker (search "CSP nonce").

export function buildCsp(): string {
  const directives = [
    "default-src 'self'",
    "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.googletagmanager.com https://www.google-analytics.com https://apis.google.com https://js.stripe.com",
    "style-src 'self' 'unsafe-inline'",
    // img-src is the narrow allowlist of hosts we actually load images from:
    // YouTube video thumbnails (i.ytimg.com); YouTube channel avatars on BOTH
    // the legacy yt3.ggpht.com host AND the modern yt3.googleusercontent.com
    // host (Innertube returns either depending on the channel); Google
    // profile pics (lh3.googleusercontent.com); and the GA tracking pixel.
    // data: + blob: cover inline previews. Tightened in PR #46 from the
    // wildcard `https:`; `yt3.googleusercontent.com` added 2026-05-12 after
    // entropy scan caught the missing host (channel avatars were rendering as
    // broken-image placeholders because the CSP blocked the fetch).
    "img-src 'self' data: blob: https://i.ytimg.com https://yt3.ggpht.com https://yt3.googleusercontent.com https://www.google-analytics.com https://lh3.googleusercontent.com https://www.google.com https://www.google.com.au",
    "font-src 'self' data:",
    // connect-src is enumerated to the four googleapis hosts we actually call:
    // firestore (data reads), securetoken (session-cookie exchange), identitytoolkit
    // (Auth REST), oauth2 (Google sign-in token exchange). Tightened in PR #46
    // from the wildcard `https://*.googleapis.com` (covers hundreds of services).
    // GA4 fans out beyond www.google-analytics.com — analytics.google.com is
    // used for some regional/feature-flag routing, stats.g.doubleclick.net for
    // cross-site signals, and www.google.com for the Ads-audiences pixel.
    // Without these, the prod console fills with "Refused to connect... CSP"
    // errors and a chunk of the funnel telemetry is silently dropped.
    "connect-src 'self' https://firestore.googleapis.com https://securetoken.googleapis.com https://identitytoolkit.googleapis.com https://oauth2.googleapis.com https://www.google-analytics.com https://analytics.google.com https://stats.g.doubleclick.net https://www.google.com https://api.stripe.com https://*.sentry.io",
    // frame-src must include the Firebase Auth authDomain. signInWithPopup
    // opens a real popup window AND creates an invisible iframe at
    // <authDomain>/__/auth/iframe for state coordination (FedCM-style
    // session management). Without firebaseapp.com here the iframe is
    // blocked and the popup flow stalls — Firebase surfaces it as
    // auth/popup-closed-by-user because the SDK can't complete the
    // handshake. We allow the whole *.firebaseapp.com space so the
    // authDomain env var can change without a CSP edit; the wildcard is
    // narrow (single Google-owned suffix). Stripe entries support the
    // (currently unused) embedded Elements path.
    "frame-src https://js.stripe.com https://hooks.stripe.com https://*.firebaseapp.com",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self' https://checkout.stripe.com https://billing.stripe.com",
    "frame-ancestors 'none'",
    "upgrade-insecure-requests",
  ];
  return directives.join("; ");
}

export function applySecurityHeaders(headers: Headers): void {
  headers.set("Content-Security-Policy", buildCsp());
  headers.set("Strict-Transport-Security", "max-age=63072000; includeSubDomains; preload");
  headers.set("X-Frame-Options", "DENY");
  headers.set("X-Content-Type-Options", "nosniff");
  headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
  headers.set("Permissions-Policy", "camera=(), microphone=(), geolocation=(), interest-cohort=()");
  // Cross-Origin-Opener-Policy: `same-origin-allow-popups` is the
  // Firebase-recommended value for sites that use signInWithPopup. Our
  // app is hosted on App Hosting (e.g. leapedge-clip--<hash>.run.app)
  // while Firebase Auth's popup handler loads at the project's
  // firebaseapp.com authDomain (leapedge-845eb.firebaseapp.com). After
  // the OAuth round-trip, the popup posts the credential back to
  // `window.opener.postMessage(...)`. A bare `same-origin` COOP value
  // (Chrome's emerging default in cross-origin-isolation contexts) would
  // sever that link and surface as `auth/popup-closed-by-user` — the
  // Firebase SDK can't distinguish "user closed the popup" from
  // "opener became null because of COOP." `same-origin-allow-popups`
  // keeps the isolation invariant for everything except the popups we
  // explicitly opened, which is exactly the safety/usability balance
  // Firebase's docs recommend.
  headers.set("Cross-Origin-Opener-Policy", "same-origin-allow-popups");
}
