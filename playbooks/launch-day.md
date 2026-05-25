# Launch day

Product Hunt + X thread + the first 72 hours of attention. Distilled from real launches; tuned for a solo builder who doesn't have a launch agency, a community manager, or sleep on Tuesday night.

## What "launch" means here

You're shipping the product to the public, not to your friends. Three goals, ranked:

1. **Get real users.** Strangers signing up, using the product, paying. Vanity badge is downstream.
2. **Get feedback that changes the next month.** Bad reviews are inputs, not insults.
3. **Get the launch badge.** PH "#1 product of the day" or top-trending X thread are useful for future credibility, but not the win condition.

Don't optimize for #3 at the cost of #1 or #2.

## T-14 days: are you actually ready?

Pre-mortem the next four weeks. If any of these are false, **postpone**:

- [ ] Stripe is live (not test mode) for at least 7 days. Real card subscribed + canceled. Webhook delivering 200s. Auto-recovery exercised at least once (test→live migration, manual customer wipe).
- [ ] `/qa` of the signup flow passes on a fresh browser profile. Sign in with Google works in Safari, in-app browsers (Twitter app, Instagram), and Chrome. Email sign-in works.
- [ ] Top 10 Sentry issues from the last 7 days each have a runbook under `docs/runbooks/`. No "WTF is this" issues. Inbox-zero on the day before launch.
- [ ] Daily cost cap headroom is ≥5x current peak day. A flash crowd cannot trigger false 429s.
- [ ] You have a "kill switch" wired for every money-critical path. Feature flag, route 503, Stripe pause. See `docs/12-incident-response.md`.
- [ ] You're on-call for the launch window. Phone notifications working for Sentry. AppHosting / Firebase / Stripe consoles bookmarked. Coffee ready.
- [ ] You can answer "what does this cost me per active user?" with a real number from `llmCalls` data. If LLM cost > LTV per tier, fix pricing first.
- [ ] Your **brand voice** in onboarding email + landing + pricing is consistent. Read all three side-by-side. Different tones = users feel something is off.
- [ ] Privacy + Terms + Disclaimer are written + linked from the footer. Not lawyer-reviewed (that's fine for an MVP), but written.

If 2+ are false: postpone. Cancellable PH submission > public stumble.

## T-7 days: assets ready

### Product Hunt

- **Tagline** (60 chars max). Lead with the user verb, not the feature.
  - Good: "Turn trading videos into trade ideas."
  - Bad: "AI-powered trading research with verbatim citations."
- **Description** (260 chars). Five sentences max. Anchor in user outcome.
- **Gallery** (4-6 images). First image is your hero shot. Subsequent images show the actual product UI in action. Don't use stock photography. Don't use AI-generated logos. **Mobile screenshots count** — PH viewers swipe on phones.
- **First comment** (200 chars). YOU post this as the maker. Sets the tone for the comment thread. End with a question that invites a reply (e.g. "what's the worst trading video you've watched lately?").
- **Topics** (3 tags). Pick the highest-traffic ones that genuinely fit. AI is always good. Then your category (Finance, Productivity, Developer Tools, etc.). Then one specific (Retail Trading, Knowledge Management, etc.).
- **Demo video** (optional, 30-60sec). If you can record one in <2 hours total: yes. If it's a half-day project: skip and use a screenshot carousel instead.

### X thread

- **Hook tweet** (the first one). 4 lines max. Open with a result, not a setup. Examples:
  - "Today I'm shipping leapedge.clip. Paste a YouTube trading video, get a structured thesis with quote-citations. Built it in 6 weeks. Here's how it works ↓"
- **6-12 follow-up tweets.** Each one stands on its own (people read in random order). Show real product screenshots. Numbers > adjectives. Limit each tweet to one idea + one image/video.
- **Final tweet** (the CTA). Single link. Either to PH (during launch day) or to your landing (after).
- **Pinned tweet on profile** updated to the launch thread for the week.

### Newsletter / mailing list

If you have one:
- **Pre-launch email** (T-3 days). "Launching Tuesday on Product Hunt. Here's the early-access code that's valid today only." This pre-seeds upvotes from people who already know you.
- **Launch-day email** (morning of). "Just launched. Here's how to support." Don't send if your list is < 50 people — too small to move PH ranking and you burn your warm-up.

### Coupons

In Stripe Dashboard, mint a launch-special promotion code (e.g. `BETAFREE` — 100% off forever, capped at N redemptions). Distribute it ONLY via PH (in your maker comment) and the launch X thread. This makes early supporters feel rewarded and avoids freeloaders.

See `.claude/rules/marketing.md` for the dual-coupon pattern (founder code + launch special).

## T-3 days: dry run + scheduling

### Dry run

Sign up as a brand-new user with a clean browser profile. Email you've never used. Go through:

1. Landing → CTA click
2. Sign in (try email AND Google; try Safari AND a private window)
3. First analyze action
4. Subscribe to Pro using the launch-special coupon
5. Cancel subscription via Settings → Billing
6. Sign out
7. Sign back in
8. Use the cached state (do you see your prior analyses?)

If any step has a moment of "wait, that's weird" — fix before launch. The PH crowd does NOT forgive a 5-second friction at signup.

### Schedule the PH submission

PH launches are 12:01am Pacific Time. Schedule the submission in PH the day before. You don't need to be awake at 12:01am Pacific — submissions go live automatically and PH ranks within a 24-hour window.

For Australia (UTC+10): 12:01am PT = 17:01 (5pm) the same day in Sydney/Melbourne. Good — you can do final checks at lunch and watch the launch start before dinner.

For Europe: 12:01am PT = 9am CET. Wake up, brew coffee, hit live.

Plan your day:

- **T-1 day:** Final dry-run in the morning. Eat early. Sleep early.
- **Launch day:** Block 4 hours during the highest-traffic window for your geo. For US-focused: 10am-2pm PT. For EU-focused: morning your time. For AU-focused: morning-to-afternoon your time. Avoid Friday launches; Tuesday and Wednesday have the highest engagement.

### Schedule the X thread

Send the hook tweet at 9am your time on launch day. Don't pre-schedule via Buffer — Twitter algorithm de-prioritizes scheduled posts on launch-day-style traffic. Manual send.

Reply to your own hook with the rest of the thread within 5 minutes. Then go on with your day; reply to comments as they come.

## T-1 day: final checks

- [ ] Sentry inbox is zero. Anything new firing today gets a runbook now, not tomorrow.
- [ ] DNS / SSL on your domain shows valid for ≥30 days remaining.
- [ ] No deploys planned for the next 48 hours unless they're hotfixes. Quiet deploys = predictable behavior.
- [ ] The launch-special coupon redemption count in Stripe Dashboard is at 0. Verify.
- [ ] Your laptop is fully charged. Your phone is fully charged. You have a backup laptop or hotspot for "internet outage at 12:05am" scenarios.
- [ ] Tell people you're launching. Anyone who said "tell me when it's live" — text them tonight with the launch URL.
- [ ] Pre-write 3-5 PH comment replies for likely questions ("how does this compare to X?", "do you have a free tier?", "is this open source?"). Save in a notes app. You'll paste them on launch day.

## Launch day timeline

Times in YOUR local zone (substitute as needed).

### Morning (or wake-up)
- Check Sentry. Anything firing? Fix or runbook.
- Verify PH submission went live. Spot the launch URL.
- Send the X hook tweet. Reply with the rest of the thread.
- Send launch-day email if you have a list.
- Post in your communities (Discord, Slack, IndieHackers — wherever you're a regular). Don't spam ones you're not active in.

### Mid-day (peak traffic)
- Reply to every PH comment within 1 hour. Even "🔥" deserves a "thanks 🙏". Real conversation matters.
- Reply to every X reply. Quote-tweet anyone who shared with their own positive comment.
- DON'T compulsively check the leaderboard ranking. Set a 90-minute timer. Check at the timer.
- DON'T deploy. Even hotfixes. Wait for the day to end. Hotfix Wednesday.

### Afternoon
- Reply to feedback in DMs.
- Take screenshots of milestone moments (ranking, comment count, signups). You'll use these in retrospectives.
- Send a "thank you" reply on X or PH every couple hours, mentioning a specific person who left a great comment.

### Evening
- One last Sentry sweep. Any new issues from real traffic?
- Read the day's signups in your admin console. Note common patterns (which tier, which country, which referrer).
- Send a "summary of the day" tweet — gratitude + a stat ("100 signups, 8 paying, 2 truly useful pieces of feedback"). Keep numbers honest.
- Sleep. The next day is not over.

## First 24 hours: monitor + respond

What you're watching:

- **Sentry** — any new `site:` tags appearing? Especially auth flow, payment flow, LLM pipeline. Triage every hour for the first 6 hours.
- **Stripe Dashboard** — successful subs incrementing? Any decline rate spikes (>5% suggests pricing-page-to-Checkout flow has friction)?
- **Cloud Functions logs** — daily-digest cron firing? LLM cost trending? Anything in red?
- **GA4** — `checkout_started` → `checkout_completed` conversion. If <40%, your pricing-to-Checkout flow has friction. Bookmark for post-launch fix.
- **Twitter notifications** — every reply to your thread is a potential conversation. People who reply at hour 6 are real users, not pre-warmed friends.

Patterns to act on:

- **Same Sentry issue firing 5+ times** in the first 2 hours → triage now, even if it means a hotfix. Wait until 7pm to deploy if possible (lower traffic, smaller blast radius for the deploy itself).
- **Multiple users reporting the same UX confusion** (in DMs, PH comments, X replies) → write it down. Don't fix today. Make it the priority for tomorrow morning.
- **A specific demographic outsmarting your pricing** (e.g. all signups choosing Free, none upgrading) → the value prop on Free is too generous OR Pro doesn't unlock enough. Don't change pricing on launch day; analyze for the post-launch retro.

## First 72 hours: ride the long tail

PH spikes on day 1, plateaus on day 2, dips on day 3. X spikes for 18 hours, then 80% drop. Newsletter mentions in adjacent publications (TLDR, Hacker Newsletter, etc.) can hit on day 2-7 if you've pitched them.

What to do:

- **Day 2 morning:** Post a "day 1 retrospective" tweet thread (or short PH comment). 5 stats + one thing you learned. This re-engages the algorithm.
- **Day 2-3:** DM specific people who left thoughtful PH comments. Offer them a 15-minute call. Real conversation beats pricing-page tweaks for understanding user motivation.
- **Day 3-4:** Write a "behind the scenes" blog post or thread. How long it took, the stack, the failed experiments. Doubles as content marketing AND signals authenticity.
- **Day 5-7:** Begin shipping the polish PRs based on launch feedback. Use `/autoplan` for each — solo capacity is one feature at a time.

## When the launch flops

Sometimes a launch lands flat. Symptoms:
- < 50 signups on launch day
- PH ranking outside top 20
- X thread hits < 1% engagement on the hook tweet

The reasons are usually one (or more) of:

1. **Timing was wrong** — competing launch the same day, Friday afternoon, holiday week
2. **Tagline didn't land** — viewers couldn't grok the product in 3 seconds
3. **Pricing scared the click** — visible pricing on PH card without context loses casual interest
4. **The product genuinely isn't ready** — and the launch surfaced that mismatch

What NOT to do:

- ❌ Re-launch immediately. PH allows it but the second launch usually flops harder.
- ❌ Buy fake upvotes / engagement. PH detects, and the reputation damage outlasts the launch.
- ❌ Get defensive in PH comments. Critics on launch day are users who took 30 seconds to engage; treat their feedback as priceless.

What TO do:

- ✅ Read every comment, screenshot the critical ones, journal what they tell you about the actual user.
- ✅ Sit on the data for a week. Resist the urge to "fix" the launch. The next launch is a quarter away anyway.
- ✅ Ship the polish PRs. The first 50 users became 50, full stop — make them love the product so they bring 50 more organically.

## Post-launch retro (within 7 days)

Open `QUALITY_SCORE.md`. Add a session entry:

```
## Session N — Launch retro YYYY-MM-DD

**Numbers:** N signups, N paid, $X MRR added, N PH upvotes, N X thread impressions, M% conversion checkout → completed
**What worked:** [1-3 things]
**What didn't:** [1-3 things]
**Surprising signal:** [what didn't match your prediction]
**Next-cycle focus:** [the one thing that should change before next launch]
```

Three reasons to write this:

1. **Closes the office-hours prediction loop.** You predicted X% conversion in Phase 1. Did it land? If not, why?
2. **Builds the launch-day playbook for the NEXT launch.** Your second launch is informed by your first; your fifth is informed by all four.
3. **Honest accounting.** You can't fix what you don't measure. Vanity-only retros help no one.

## What you can reuse for the next launch

After 1-2 launches, you'll have:

- A reusable PH submission template (tagline structure, gallery composition, first-comment formula)
- A reusable X thread structure
- Pre-written replies for common questions
- A "what to watch" Sentry/Stripe/GA dashboard you can re-use
- A runbook for "PH spike traffic" — auto-scale assumptions, cost-cap headroom, etc.

That's the compounding loop. Each launch teaches you something the next one starts with.

## The single hardest thing

Solo launches are emotionally exhausting. You're the founder, the engineer, the support, the marketer, and the person reading every critical comment.

The protective move: **plan one easy quiet activity for launch evening.** Walk. Cook. Watch something undemanding. Whatever the launch outcome, you need to detach from the screen to keep your head clear for tomorrow.

Sleep is non-optional. The 72-hour window is more important than the first 8 hours. You can't sprint that long. Pace yourself.
