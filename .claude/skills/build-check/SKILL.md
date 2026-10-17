---
name: build-check
description: >-
  Production-readiness gate scaled to the app's blast radius: T0 personal sandbox, T1 trusted few (client or team),
  T2 public and free, T3 paid product or app-store submission. Use it whenever the user starts a new app or project,
  asks to deploy, ship, publish, launch, release, go live, submit to the App Store or Play Store, hand off to a client,
  or asks "is this ready", "what am I missing", "is this secure enough", "am I building this properly". Also use it
  when they mention customers, users signing up, selling, subscriptions, SaaS, or payments, or when a personal tool
  is about to be shared with anyone else. Records the tier once in .buildcheck.yml and keeps a short list of
  never-rules in mind while writing backend, auth, or LLM code. Does not review code correctness, UI design, or CI syntax.
---

# build-check

A checklist only works when the reader believes every item on it. Running a 40-row product checklist on a weekend
script buries the one thing that matters (a leaked key, an uncapped LLM bill) in noise and trains the user to ignore
the tool. So: detect what the app *has* first, then ask how far it will *travel*, and only print what is required.

## Tiers (blast radius: who gets hurt, who can punish you)

| Tier | Name    | Definition                                                                              |
|------|---------|-----------------------------------------------------------------------------------------|
| T0   | Sandbox | The author, or friends playing with it, no one relies on it, no one else's data. Failure costs an afternoon. |
| T1   | Trusted | A few named people (client, team) rely on it. Failure costs reputation and their data.  |
| T2   | Public  | Strangers use it for free. Failure is public, abusable, and may trigger privacy law.    |
| T3   | Product | Strangers pay, or Apple/Google review it. Failure costs money, legal exposure, removal. |

Escalation rules that override the user's guess: payments present → payment rows are T3 regardless; app-store target
→ T3; unknown-stranger traffic → at least T2; someone else's real data → at least T1. When these rules already fix the
tier, state the tier and the rule in one line and skip the question.

## Decision order

1. **Features first.** Run `bash <skill-dir>/scripts/detect.sh` from the repo root (read-only, no network, ~0.3s).
   It prints one line of `key=value` pairs. Every checklist row carries a tag that maps to one of those keys
   (`[auth]`, `[db]`, `[llm]`, `[payments]`, `[email]`, `[analytics]`, `[mobile]`, `[deps]`, `[api]`, `[ui]`,
   `[public-web]`, `[uploads]`, `[metered]`); the row is dropped when its key is `no`. No auth means no password-reset
   row, full stop. A wrong feature guess creates a false positive the user learns to ignore, which is why this is
   observable, not asked. The script reads manifests, so a dependency with no call site still counts as present:
   per-instance rows ("every call", "every route") then PASS vacuously and existence rows (a handler, a page, a test
   file) FAIL. Say so in one line, `Declared but not wired: llm, auth`, so the user knows the FAILs mean unbuilt, not misbuilt.
2. **Tier second.** Read `.buildcheck.yml` if present. Otherwise propose a tier from signals (store config or
   payments → T3; "client", "team" → T1; nothing → T0) and confirm in one question with the default stated.
3. **Floor always.** The never-rules below apply at every tier because they cost minutes to follow and days to recover from.

## Workflow

**INTAKE** (new project, or no `.buildcheck.yml`): run detect.sh, propose tier, one confirmation question unless an
escalation rule already fixes it, write `.buildcheck.yml`. Do not load the checklist. About 100 tokens of output.
When an AUDIT trigger arrives with no state file, do INTAKE and AUDIT in the same turn: ask, state the default you are
proceeding on, and audit against it; the user corrects the tier by replying.

**INLINE** (while writing any code): hold only the never-rules in mind. Fix violations silently as you write; mention
in one line only if the user's instruction forced the choice.

**AUDIT** (ship, deploy, launch, "is this ready", client handoff, store submission): run detect.sh, read
`.buildcheck.yml`, open `references/checklist.md` and apply only the rows where this tier's column is ● or ○ and the
feature tag is present. Verify each row by the command in its Verify column; never grep by hand for things the script
already reports. Items already `WAIVED` or `MANUAL_CONFIRMED` in the state file are not re-litigated unless the tier
has gone up. If detect.sh now contradicts the stored state (new features, secrets SUSPECT), the fresh audit wins and
overwrites it; waivers survive only while the tier is unchanged. Emit the report below, then update `.buildcheck.yml`.

**PROMOTE** (a trigger phrase implies a higher tier than the one recorded, e.g. "send this to the client", "start
charging"): ask "Promote to T<n>?" once with the implied tier, then run AUDIT. Print rows newly required by the higher
tier plus anything that is failing from the floor (never-rules, secrets, spend cap) or the payment rows; those are
never hidden by a promotion diff. No state file means this is INTAKE, not PROMOTE.

Open `references/llm-security.md` only when you are about to fix or hand-verify an LLM, auth, or security row; an
audit never needs it. The store-review rows for `[mobile]` at T3 live at the bottom of `references/checklist.md`.

## Never-rules (every tier)

1. No secrets in the repo. `.env*` gitignored, keys read from env, `secrets_in_repo=clean` from detect.sh.
   A leaked key is scraped within minutes; if one ever landed in git history, rotate it, do not just delete it.
2. Parameterised queries only. No string-built SQL or NoSQL filters.
3. No `eval`, `exec`, `new Function`, shell interpolation, or `subprocess(shell=True)` on user input.
4. Where auth exists, every mutating endpoint checks the session *and* resource ownership (`WHERE user_id = ?`).
   IDOR is the most common real bug in vibe-coded apps.
5. Every LLM call sets `max_tokens` and a client timeout. Unbounded output is an unbounded bill and a hung request.
6. User content goes in `user` turns inside delimiters, never spliced into the system prompt. Content inherits
   instruction authority once it is in the system role.
7. Model output is data: never rendered as raw HTML, never passed to a shell or a query.
8. Dependencies come from a committed lockfile, installed with the frozen command (`npm ci`, `uv sync`, etc.).
9. Debug mode, default credentials, and stack traces in responses are off outside local dev.
10. Any metered API (LLM, cloud) has a provider-side hard spend cap. This is the one item that is MANUAL even at T0.
    If a key ever reached a commit, rotate it before the next push; deleting the line does not remove it from history.

## State: `.buildcheck.yml` at repo root

```yaml
tier: T1                    # T0|T1|T2|T3
features: [auth, db, llm]   # the checklist tags detect.sh found; user may add or remove
last_audit: 2026-10-17
verdict: NOT_READY          # SHIP | SHIP_WITH_WAIVERS | NOT_READY
items:                      # only non-PASS rows; PASS is recomputed every audit
  rate-limit:  {status: WAIVED, reason: "behind Cloudflare WAF"}
  backups:     {status: MANUAL_CONFIRMED, note: "Supabase PITR on"}
  email-auth:  {status: MANUAL}
  error-track: {status: FAIL}
```

Statuses: `PASS | FAIL | MANUAL | MANUAL_CONFIRMED | WAIVED`. `MANUAL` is pending confirmation. A waiver carries a
reason and is permanent for that tier.

## Audit report (fixed template, no prose around it)

```
BUILD-CHECK · T2 Public · features: auth, db · 23 PASS · 3 FAIL · 2 MANUAL · 2 WAIVED

| Item           | Why it matters                              | Fix |
|----------------|---------------------------------------------|-----|
| error-tracking | you will not know when users hit crashes    | S   |
| rate-limit     | one script can run up your bill             | M   |
| privacy-policy | required once you collect accounts          | S   |
| MANUAL backups | confirm DB backups or PITR are on           | –   |
| MANUAL domain  | confirm custom domain and HTTPS are live    | –   |

Verdict: NOT READY (3 FAIL, 2 unconfirmed)
Reply: "confirm backups, domain" · "waive rate-limit: <reason>" · "fix S" (I add the S items now)
```

Rules: print FAIL and MANUAL rows only, PASS is a count. Batch every MANUAL item into that one reply line rather
than asking per item. ○ (recommended) rows go in a single trailing line, `Recommended: a, b, c`, at most five, chosen
by what hurts first at the next tier up; never in the table. With nothing to print, drop the table and keep the header,
verdict, and Recommended line. When FAIL exceeds twelve, keep the table to the Security, LLM, Payments, and Data rows
plus `secrets`, and collapse every other section to one line, `Foundation: ci, smoke, unit, readme (4 FAIL)`, so the
dangerous rows stay visible. One framing sentence before the block is allowed in that case, nothing more.
Verdicts: `SHIP` = 0 FAIL and 0 MANUAL pending; `SHIP WITH WAIVERS` = 0 FAIL, ≥1 WAIVED; else `NOT READY`.
Fix effort: S = under 30 minutes in code, M = an hour or a new service, L = multi-day or architectural.
Always end by offering to do the S items in the same turn.
