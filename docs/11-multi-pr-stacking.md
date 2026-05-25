# 11 — Multi-PR stacking

The footgun that bit a real shipping session. Documented so it doesn't bite again.

## The shape of the bug

You're solo. You ship PR #1. While it's in review (or already merged), you start PR #2 — but you forget that PR #2's branch is based on PR #1's branch, not on `main`.

After PR #1 merges, PR #2's base is **stale**. Two things happen:

1. **GitHub may merge PR #2 onto the stale base anyway** (it's still a valid branch). The merge commit lands on the stale base — NOT on main.
2. **When GitHub deletes the source branch** after merge, the merge commit becomes **dangling** — reachable by SHA but not by any active branch. Your code is "merged" according to GitHub, but `git log main` doesn't show it.

This happened during this session with PR #120. We recovered via cherry-pick onto a fresh branch from main → PR #121 → re-merge.

## The fix you should have done

After PR #1 merges, BEFORE merging PR #2:

```bash
gh pr edit <pr-2-number> --base main
```

This rebases PR #2's base on GitHub's side. Now merging PR #2 lands the commits on main.

Alternative if you're working locally:

```bash
git checkout feat/pr-2-branch
git rebase main
git push --force-with-lease
```

(Force-push is OK here — it's your own un-merged branch, and `--force-with-lease` is safe against parallel updates.)

## How to detect after the fact

If you suspect a PR merged onto a stale base:

```bash
# After PR #1 merges + PR #2 marked merged on GitHub:
git checkout main
git pull --ff-only origin main
# Does PR #2's code actually appear?
grep -r "FunctionFromPR2" lib/  # or whatever the PR's identifier was
```

If the grep returns nothing, the PR's commits are dangling.

Recovery:

```bash
# 1. Find the dangling merge commit
gh pr view <pr-2-number> --json mergeCommit -q .mergeCommit.oid
# returns e.g. 347f0433...

# 2. Inspect what it changed
git show 347f0433

# 3. Cherry-pick the actual content commit (NOT the merge commit) onto main
git checkout -b fix/recover-pr-N-2026-XX-XX
git cherry-pick <content-commit-from-pr-2>

# 4. Push and re-PR
git push -u origin fix/recover-pr-N-2026-XX-XX
gh pr create --base main ...
```

## The prevention checklist

Before merging a stacked PR:

- [ ] Has the base PR (the one this depends on) already merged?
- [ ] If yes: have I rebased this PR's base to `main` via `gh pr edit --base main`?
- [ ] If no: am I OK with this PR potentially merging in an out-of-order sequence?

`/ship` does NOT detect this. The merge happens on GitHub's side, not in your /ship flow. The detection has to come from you.

## When stacking is worth it

You should stack PRs when:
- PR #1 introduces a new file or major refactor
- PR #2 builds on PR #1's surface in a way that doesn't reasonably wait
- You want PR #1 to ship for its own merit before PR #2's polish lands

You should NOT stack when:
- PR #2's changes could trivially be in PR #1 (just amend or recommit)
- The PRs are unrelated (just branch from main twice)
- You're tempted to stack because PR #1's review is slow (resist; landing PR #2 second prevents review concurrency anyway)

## Meta-note for future-you

The mechanical fix for stacked PRs in this repo is: after merging the base PR, run:

```bash
gh pr edit <stacked-num> --base main
```

BEFORE clicking merge on the stacked PR. Two seconds of typing prevents the cherry-pick recovery dance.

If you're stacking 3+ PRs (which you usually shouldn't), use a tool like `git-pile` or `spr` that does the rebase-chain automatically. Or just don't stack 3+.

## What went wrong in the leapedge-clip session

```
2026-05-25:
- PR #119 (/creators public surface) → merged to main
- PR #120 (share-snapshot creator-mention) → branch = feat/creators-... (stacked on #119)
- PR #119 merged. PR #120's base NOT updated.
- PR #120 clicked merge. Merge commit landed on PR #119's stale source branch.
- GitHub deleted the source branch on merge. Merge commit now dangling.
- Local `git log main` did not show the share-snapshot code.
- Recovery: cherry-pick the content commit onto fresh branch → PR #121 → re-merge.
- Total cost: ~15 minutes, no data loss, but real surprise.
```

The lesson: GitHub's "merged" UI status is not a guarantee the commits are on main. Verify by grep after every merge of a stacked PR.

---

Read next: [12-incident-response.md](12-incident-response.md)
