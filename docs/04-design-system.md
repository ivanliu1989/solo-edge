# 04 — Design system

The instrumentation-panel pattern. Distilled from leapedge-clip's design audit + post-launch polish loop.

## The DNA

Three layers, top-down:

1. **Tokens** (CSS variables) — `--canvas`, `--text`, `--line`, `--accent`, `--signal-*`. Dual theme (dark default, light explicit-or-system). Byte-for-byte parity between explicit `[data-theme="light"]` and `@media (prefers-color-scheme: light)` blocks.
2. **Primitives** — `.label`, `.terminal`, `.display`, `.signal`, `.signal-pulse`, `.signal-ring`, `.row-in`. Compose freely, never override.
3. **Components** — Built from primitives + Tailwind utilities + tokens. No raw hex anywhere.

The full template is in [templates/globals.css](../templates/globals.css). Drop it into your `app/globals.css` and edit the color values to match your brand.

## Why this specific pattern

- **Token-first survives five products.** When you change the accent from `#c8f441` to `#34d399`, every component updates without re-touching them.
- **Dual theme without next-themes.** Skips a 60KB dependency, kills the React 19 "Scripts inside React components don't execute" warning, gives you a pre-hydration bootstrap script that eliminates FOUC.
- **Signal-system is a vocabulary.** `signal` + `signal-pulse` + `signal-ring` is one design language for "activity state" — used by status pills, wordmark heartbeat, in-progress cards. Adds an instrument-panel feel without screaming "neumorphic."

## The dual-theme bootstrap pattern

`lib/theme/script.ts` exports a small string that runs at HTML-parse time (before paint) to set `data-theme` on `<html>`. No FOUC for light-mode users.

```typescript
export const THEME_BOOTSTRAP_SCRIPT = `
(function() {
  try {
    var stored = localStorage.getItem('theme');
    if (stored === 'light' || stored === 'dark') {
      document.documentElement.setAttribute('data-theme', stored);
    }
  } catch (e) {}
})();
`;
```

Render in `app/layout.tsx`:

```tsx
<head>
  <script dangerouslySetInnerHTML={{ __html: THEME_BOOTSTRAP_SCRIPT }} />
</head>
```

The `dangerouslySetInnerHTML` is intentional — React 19 won't execute inline scripts in components on re-render, so the script must come from a non-component pathway.

## Accessibility baseline (non-negotiable)

| WCAG | Solution |
|------|----------|
| 1.4.1 (color not only) | Active nav states use icon + text + border-rail, not color alone |
| 1.4.3 (contrast 4.5:1) | Body text on canvas verified for both themes |
| 2.4.7 (focus visible) | Global `:where(button, a, summary):focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }` in globals.css |
| 2.5.5 (touch target 44pt) | All interactive elements `min-h-11` or `min-h-12`; tap-only icons widened via `min-h-9` on desktop |
| Reduced motion | `@media (prefers-reduced-motion: reduce)` in globals.css neutralizes `row-in`, `signal-pulse`, `signal-ring` |

These appear in the [templates/globals.css](../templates/globals.css) baseline. Don't remove them.

## The marketing chrome pattern

`MarketingHeader` + `MarketingFooter` + JSON-LD components. Every public page renders both. Authenticated pages render their own chrome and skip these.

Conventions:

- Sticky header with `backdrop-blur-md bg-canvas/80 border-b border-line`
- Wordmark with a pulsing `signal` dot
- Right-side CTA reflects auth state (signed-in → "Open research", signed-out → "Sign in" + "Get started")
- Footer carries `Organization` + `WebApplication` JSON-LD schemas
- Disclaimer copy: "Personal research tool · not financial advice" (or your equivalent)

## The app chrome pattern

`(app)/layout.tsx` is the authenticated route group layout:

- Sticky header: wordmark + nav links (hidden on mobile) + Command palette trigger (⌘K) + ThemeToggle + Settings glyph + SignOut
- Mobile: 5-tab bottom bar (`MobileTabBar.tsx`) with `min-h-12`, safe-area-inset-bottom, active-state border-rail
- Main content: `pb-[calc(env(safe-area-inset-bottom)+5rem)] sm:pb-0` so the last row of content isn't hidden under the bottom bar on iOS

## The post-launch design polish loop

Treat as a separate, named pass (not a "while I was in there" change):

1. After launch, run `/design-review` against the live site. Get a structured audit (HIGH/MEDIUM/LOW findings).
2. Triage the findings into a PR. Group them by theme (a11y, touch targets, contrast, copy consistency, etc.).
3. Ship the polish PR via `/ship`.

Real example: the `feat/design-review-polish-2026-05-26` PR in leapedge-clip shipped 8 files / +57 / -15 in one focused pass. Fixes:

- Global `:where(button, a)` focus-visible ring in globals.css
- MobileTabBar `min-h-12` + active state border-rail (was color-only)
- Pricing strike-through `<s>` + sr-only "was" (screen-reader fix)
- Marketing footer social icons `w-11 h-11` (was 36×36, sub-target)
- EmailSubscribeBanner button `min-h-11` (was ~28px)
- `/today` mobile date label visible (was `hidden sm:block`)
- Loading-copy consistency: lowercase + trailing ellipsis

Each fix maps to a known WCAG criterion. None of them break anything. The whole PR took ~45 minutes including review and CI.

## When to invoke ui-ux-pro-max vs /design-review

- **`/ui-ux-pro-max`** — full design system generation from a product description. Use ONCE at project start. Produces tokens, type pairings, layout system, anti-patterns. Then move on.
- **`/design-review`** — audit existing implementation against the design system. Use after every major UI change. Produces actionable findings.
- **`/design-consultation`** — between design system and audit. Use when you have a specific design question ("should this be a modal or a sheet?").

## Common mistakes (from observation)

❌ **Emojis as icons.** Per-platform rendering inconsistency. Use SVG (Lucide, Heroicons, custom). The leapedge-clip MobileTabBar uses Unicode geometric chars (◉ ✓ ↗ ⌕ ◎) which is in the gray zone — it works visually, but a Lucide stroke set would give better state variants (filled-active vs outline-inactive).

❌ **Hardcoded hex in components.** Always go through tokens. If you find yourself writing `text-[#c8f441]`, add a `--color-X` token and use the Tailwind utility.

❌ **Skipping the dual-theme test.** Build with `[data-theme="light"]` and `[data-theme="dark"]` open in two tabs side-by-side. Contrast issues that pass AA on dark fail on light, and vice versa.

❌ **next-themes on React 19.** The `<ThemeScript>` component triggers the "scripts in client components don't execute" warning. Roll your own (it's 30 lines, see [templates/globals.css](../templates/globals.css) for the bootstrap pattern).

---

Read next: [05-qa-workflow.md](05-qa-workflow.md)
