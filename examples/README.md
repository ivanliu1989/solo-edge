# examples/ — intentionally empty (for now)

This directory is reserved for **anonymized real artifacts** from shipped projects:

- A real `/office-hours` brief that produced a useful insight
- A real `/autoplan` plan file with the CEO/Eng/Design review sections completed
- A real `/design-review` audit output (before / after)
- A real `QUALITY_SCORE.md` session entry that produced a promotion

These can't be synthesized convincingly — the value is in seeing actual output an actual session produced, including the imperfect parts.

## Why it's empty today

Solo-edge is distilled from [leapedge-clip](https://github.com/AtaNexus/leapedge-clip). The real artifacts live in that repo's `~/.gstack/projects/atanexus-leapedge-clip/` history. They haven't been anonymized + copied here yet because the cost of doing it well (real numbers, real screenshots, no PII leakage) is higher than the immediate value.

## How to contribute

If you've shipped with the solo-edge conventions and have an artifact worth sharing:

1. Anonymize it — strip uid, email, customer-specific names, internal URLs
2. Add a one-line header: `# Example: <artifact-type> from <product-name>, <date>`
3. Drop into the appropriate subdirectory:
   - `examples/office-hours/`
   - `examples/autoplan/`
   - `examples/design-review/`
   - `examples/quality-score/`
4. Open a PR

The bar is "would this save a future solo builder 30+ minutes of figuring out shape?"

## Until then

Real artifacts live in the [leapedge-clip](https://github.com/AtaNexus/leapedge-clip) repo itself — its `QUALITY_SCORE.md` is the most useful public reference (real session log, real promotions to CI gates). Plans and design audits live in `~/.gstack/projects/atanexus-leapedge-clip/` on the author's machine and aren't published; if you want to see one, ask Ivan.
