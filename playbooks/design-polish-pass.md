# Design polish pass

The post-launch design review loop. Treat as a separate, named pass — not a "while I was in there" change.

## When to run it

- After every major UI launch (new page, new flow, redesigned section)
- Before major marketing pushes (Product Hunt, X launch, press)
- Quarterly minimum on the marketing surface (landing, pricing, FAQ)
- After any user complaint about visual issues

Don't run it for:
- Backend-only changes
- Single-component tweaks (the multi-agent review army handles those during `/ship`)

## The workflow

### Step 1: Run /design-review

```
> /design-review
```

The skill audits the current implementation against a baseline design system (it reads `templates/globals.css` or your equivalent for tokens; it reads `.claude/rules/marketing.md` for marketing conventions).

Output is structured findings:

```
HIGH (a11y or visual quality issues that would harm users)
[H1] components/MobileTabBar.tsx — touch target ~38px, below WCAG 2.5.5 44pt
[H2] app/pricing/page.tsx — strike-through prices read aloud as "8 dollars 3 dollars 99" to screen readers
[H3] app/(app)/today/page.tsx:65 — "Local day" label hidden on mobile, users lose context

MEDIUM (polish, consistency)
[M1] Loading copy inconsistent: "Loading trends…" vs "analyzing…" vs "signing in"
[M2] MarketingFooter social icons 36×36, below 44pt
[M3] EmailSubscribeBanner button ~28px tall

LOW (nice-to-haves)
[L1] Consider Lucide for icon library — current Unicode glyphs vary across platforms
[L2] hero "trade ideas." display heading — consider dropping trailing period (style choice)
```

### Step 2: Triage into a focused PR

Pick a batch. Don't do all of them in one PR — keep the scope to "post-review a11y polish" or "post-review copy consistency."

For the leapedge-clip example PR (`feat/design-review-polish-2026-05-26`):

- Selected: H1, H2, H3, M1, M2, M3 (HIGH + obvious MEDIUM)
- Deferred: L1, L2 (taste / future) + BillingSection CTA hierarchy (would be a separate copy/UX decision PR)

### Step 3: Branch + implement

```bash
git checkout -b feat/design-review-polish-YYYY-MM-DD
```

Implementation pattern for each finding:

**Touch targets** — change classes:
```diff
- py-2.5
+ min-h-12 py-2
```
Add inline comment explaining the WCAG criterion.

**Screen reader fixes** — wrap or add `sr-only`:
```diff
- <span className="line-through">$8</span>
+ <s className="text-text-fade text-[1.1rem]">
+   <span className="sr-only">was </span>$8
+ </s>
```

**Focus rings** — add global rule in `globals.css`:
```css
:where(button, a, [role="button"], summary):focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 2px;
}
```
The `:where()` keeps specificity at 0 so per-component overrides still win.

**Color-only indicators** — add a secondary signal (border, glyph, sr-only text):
```diff
- className={active ? "text-accent" : "text-text-mute"}
+ aria-current={active ? "page" : undefined}
+ className={`border-t-2 ${active ? "text-accent border-t-accent" : "text-text-mute border-t-transparent"}`}
```

### Step 4: Verify against the design system

For each fix, ask:
- Does it use a token (`--accent`, `--text-soft`) instead of a hex?
- Does it survive dark + light mode? Open both in side-by-side tabs.
- Does it match the existing voice? (lowercase + ellipsis, etc.)
- Does it touch something the multi-agent review army would catch differently? (run `/ship` to confirm)

### Step 5: /ship

`/ship` runs the multi-agent review on the polish PR. It will:

- Catch any focus-ring you missed (the global rule covers most, but a custom outline elsewhere might conflict)
- Catch any color-only state that you didn't add a secondary indicator for
- Surface auto-fixable findings and apply them

Re-run `/ship` if it commits fixes. Push. PR opens with the full diff.

### Step 6: Manual verification BEFORE flipping out of draft

Most design fixes can't be fully verified in CI. You need to do these by hand:

- **Tab through the page.** Does the focus ring appear on every interactive element? Use a real keyboard, not Chrome DevTools.
- **375px viewport.** Open Chrome DevTools at 375×667 (iPhone SE). Are touch targets 44pt or larger?
- **Screen reader.** macOS: VoiceOver (Cmd+F5). On `/pricing`, does "was 8 dollars, 3 dollars 99 per month" announce correctly?
- **Both themes.** Open in two tabs: `data-theme="light"` and `data-theme="dark"`. Contrast acceptable in both?
- **Reduced motion.** macOS: System Settings → Accessibility → Display → Reduce motion. Animations neutralize?

If any fails: don't merge. Add a commit.

### Step 7: Merge + observe

After merge:
- Quick Sentry check: any unexpected captures from the changed pages?
- GA event sanity: still firing? Page-view counts still working?
- One-week retro: any user feedback about the polish?

## Real example: leapedge-clip PR #122

Commit message:

```
fix(ui): post-review a11y + touch-target polish pass

- Add global :where() focus-visible ring so tab users can see where they are
- MobileTabBar: min-h-12 + active-state border-rail (color-only was WCAG 1.4.1 risk)
- /pricing: strike-through prices use <s> + sr-only "was"
- MarketingFooter social icons w-11 h-11 to clear 44pt
- EmailSubscribeBanner button min-h-11
- /today date label always visible; "Local day · " + "(tz)" collapse on mobile
- Loading-copy consistency: lowercase + trailing ellipsis
```

8 files / +57 / -15. CI green in 2m25s. Total time including review: 45 minutes.

Lessons that informed THIS playbook:

- **The `[skip docs]` escape hatch is appropriate** for class-only / sr-only / copy changes. The docs gate is for behavior; polish PRs don't change behavior.
- **The defense-in-depth pattern** (global rule + per-component min-w-0) survives future refactors. The grid container's `[&>*]:min-w-0` and HistoryChartInner's `min-w-0` together mean any future caller is covered.
- **One PR per polish theme, not one PR per finding.** The 8-file PR is faster to review than 8 single-file PRs.

## What you should NOT do in a polish pass

❌ **Refactor while polishing.** "While I was in the file, I noticed..." — STOP. Make a TODO. Refactor is a separate PR.

❌ **Add new features.** The point is to polish what's there, not add new surface.

❌ **Skip the manual verification.** CI doesn't catch focus rings (no VRT) or screen-reader announcements. Your hands + ears do.

❌ **Run /design-review twice in a row on the same diff.** The model has already calibrated. Run it once, fix what it found, then move on.

## Frequency

A new product on `/design-review`:
- Right after launch — full audit, big PR
- 2 weeks post-launch — touch-up after real users provided feedback
- Then quarterly — slow drift catch

A mature product:
- Quarterly on marketing surface
- After every major UI change
- Before any press / launch event

## How this compounds

Every polish PR teaches you something. Capture it:

1. The pattern (e.g. "focus rings via globals.css :where() rule") goes into `templates/globals.css` so it's the default for the next project.
2. The criteria (e.g. "min-h-11 for touch targets") goes into `.claude/rules/marketing.md` so it's the rule for future PRs.
3. The audit (the `/design-review` findings) goes into `docs/design-audits/{date}.md` so you have history.

After 5 polish passes, the next product starts with all 5 lessons already baked in. That's the compounding.
