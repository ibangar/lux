# Checklist matrix

Legend: `-` not needed · `○` recommended · `●` required. `[tag]` = conditional on a detect.sh key (`[deps]`=deps,
`[api]`=api, `[ui]`=ui, `[public-web]`=public_web, `[uploads]`=uploads, `[metered]`=metered, others by name); skip the
row entirely when the key is `no`, at any tier. Result states: PASS (evidence found), FAIL (evidence of absence),
MANUAL (cannot be verified from the repo; batch into one confirmation line). Verify column assumes detect.sh output
is in hand; `d:` means read it from that line. Fix: S under 30 min, M an hour or a new service, L multi-day.

## Foundation

| Item (key)                | T0 | T1 | T2 | T3 | Verify                                                                                     | Fix |
|---------------------------|----|----|----|----|--------------------------------------------------------------------------------------------|-----|
| secrets (secrets)         | ●  | ●  | ●  | ●  | `d:secrets_in_repo=clean`; `.env.example` exists if the app reads env; if `.git` exists, `git log -p -S'sk-' --all` is empty | S |
| provider spend cap `[metered]` (spend-cap) | ● | ● | ● | ● | MANUAL: hard monthly cap and a billing alert in the provider console         | S   |
| in-code budget `[llm]` (llm-budget) | - | ● | ● | ● | a per-user and global daily token budget check precedes each call site                  | M   |
| README (readme)           | ○  | ●  | ●  | ●  | `d:readme`; `grep -c '^## ' README.md` ≥ 3 covering setup, env vars, deploy                | S   |
| lockfile `[deps]` (lockfile) | ○ | ● | ●  | ●  | `d:lockfile`; CI uses frozen install (`npm ci`, `uv sync --frozen`, `bundle install --deployment`) | S |
| smoke test `[deps]` (smoke) | ○ | ●  | ●  | ●  | `d:tests`; at least one test boots the app or hits the core path; CI runs it               | S   |
| input validation `[api]` (validation) | ○ | ● | ● | ● | every route body/query parsed by zod, pydantic, joi, or strong params before use           | M   |
| HTTPS + redirect (https)  | -  | ●  | ●  | ●  | MANUAL unless platform config (vercel, netlify, fly) forces it; no `http://` API bases     | S   |
| CI (ci)                   | -  | ○  | ●  | ●  | `d:ci`; workflow has `run:` steps for test and build on PR                                 | M   |
| staging / previews (staging) | - | ○ | ● | ● | preview deploys in platform config, or `staging` in CI/deploy files; else MANUAL          | M   |
| rollback plan (rollback)  | -  | ○  | ●  | ●  | `grep -ril rollback README* docs/`; migrations have `down`; platform keeps prior deploy    | S   |
| dependency audit `[deps]` (dep-audit) | - | ○ | ● | ● | `.github/dependabot.yml` or `renovate.json`, or CI runs `npm audit`/`pip-audit`/`govulncheck` | S |
| unit tests (unit)         | -  | ○  | ●  | ●  | `find . -name '*.test.*' -o -name 'test_*.py' \| wc -l` ≥ 3, excluding node_modules        | M   |
| regression / E2E (e2e)    | -  | -  | ○  | ●  | playwright or cypress config plus ≥1 spec on signup, checkout, or the core flow            | M   |
| multi-device `[ui]` (devices) | - | ○ | ● | ● | mobile `viewport` or `devices[` in E2E; `@media` rules present                            | M   |
| slow network (slow-net)   | -  | -  | ○  | ●  | `loading.tsx`, `Suspense`, `Skeleton`, or spinner components; E2E throttling if any        | M   |
| custom domain (domain)    | -  | ○  | ●  | ●  | MANUAL                                                                                     | S   |
| semver + changelog (changelog) | - | ○ | ○ | ● | `CHANGELOG.md` or release tags                                                             | S   |
| license compliance `[deps]` (licenses) | - | - | ○ | ● | `license-checker` / `pip-licenses` output has no GPL/AGPL in a closed-source product; MANUAL when deps are not installed | S |

## Security (see llm-security.md for what done looks like)

| Item (key)                         | T0 | T1 | T2 | T3 | Verify                                                                          | Fix |
|------------------------------------|----|----|----|----|---------------------------------------------------------------------------------|-----|
| auth on every endpoint `[auth]` (endpoint-auth) | - | ● | ● | ● | enumerate routes (`app/api/**/route.*`, `pages/api/**`, `router.(get\|post)`, `@app.(get\|post)`, `routes.rb`); each mutating one has a session check and ownership predicate; print the unprotected list | M |
| password reset `[auth]` (pw-reset) | -  | ●  | ●  | ●  | `grep -rE 'reset-password\|forgot\|resetPassword'`; auto-PASS if auth=clerk,supabase,firebase,auth0,kinde | M |
| email verification `[auth]` (email-verify) | - | ○ | ● | ● | `grep -rE 'verify-email\|emailVerified\|email_verified\|confirmable'`; same auto-PASS | M |
| brute-force lockout `[auth]` (lockout) | - | ● | ● | ● | backoff or lockout after 5-10 failed logins; auto-PASS for hosted auth           | S   |
| rate limiting `[api]` (rate-limit) | -  | ○  | ●  | ●  | `grep -rE 'ratelimit\|rate-limit\|@upstash/ratelimit\|express-rate-limit\|slowapi\|Rack::Attack\|throttle'` on auth and LLM routes | M |
| CORS allowlist `[api]` (cors)      | -  | ○  | ●  | ●  | `grep -rn 'cors\|Access-Control-Allow-Origin'` shows a list, not `*` with credentials | S |
| security headers `[public-web]` (headers) | - | - | ○ | ● | helmet / `secure_headers` / platform headers set CSP, HSTS, X-Frame-Options, nosniff | S |
| file upload limits `[uploads]` (uploads) | - | ● | ● | ● | size cap, MIME + magic-byte check, random server filename, stored outside web root | M |
| error responses hide traces `[api]` (no-traces) | - | ● | ● | ● | prod error handler returns a generic body; `DEBUG` from env                      | S   |
| threat model (threat-model)        | -  | -  | ○  | ●  | one page in docs/: assets, attackers, entry points                               | M   |
| secrets rotation runbook (rotation) | - | ○  | ●  | ●  | `SECURITY.md` or runbook lists every secret, where it lives, how to rotate; T2+ rotated once and dated | S |
| admin audit log `[auth]` (audit-log)        | -  | -  | ●  | ●  | append-only table: actor, action, target, timestamp, on destructive and admin actions | M |
| MFA option `[auth]` (mfa)          | -  | -  | -  | ●  | TOTP or WebAuthn enrolment exists; hosted auth providers usually PASS            | M   |

## LLM `[llm]`

| Item (key)                       | T0 | T1 | T2 | T3 | Verify                                                                                 | Fix |
|----------------------------------|----|----|----|----|----------------------------------------------------------------------------------------|-----|
| token limits (tokens)            | ○  | ●  | ●  | ●  | `max_tokens` on every call; input measured (`count_tokens`, tiktoken) or chunked; `stop_reason == max_tokens` handled | S |
| API-down fallback (llm-fallback) | -  | ○  | ●  | ●  | typed error catch (`RateLimitError`, `APIStatusError`, `APIConnectionError`); degraded UI message; T2+: second model or cached path | M |
| prompt-injection tests (injection) | - | ○ (● if tools or data access) | ● | ● | a test file with 5-10 adversarial inputs asserting no system-prompt leak, no out-of-allowlist tool call, no foreign URL | M |
| evals (evals)                    | -  | ○  | ●  | ●  | `evals/` fixtures (10-20 input/expected pairs) run by one script in CI; promptfoo, braintrust, or deepeval also count | M |
| cost-based rate limit (llm-rate) | -  | ●  | ●  | ●  | per-user and per-IP limits on LLM routes; T2+ budgets tokens per day, returns 429 with `Retry-After` | M |
| prompt logging + PII (llm-logs)  | -  | ○  | ●  | ●  | logs request id, model, usage, latency, stop_reason; T2+ redacts PII before persisting prompts | S |
| output handling (llm-output)     | ●  | ●  | ●  | ●  | model text rendered as text or sanitised markdown; structured output validated by schema | S |

## Data `[db]`

| Item (key)                 | T0 | T1 | T2 | T3 | Verify                                                                            | Fix |
|----------------------------|----|----|----|----|-----------------------------------------------------------------------------------|-----|
| automated backups (backups) | ○ | ●  | ●  | ●  | `pg_dump`/backup/`pitr` in scripts, workflows, or IaC; managed DB → MANUAL        | S   |
| restore tested (restore)   | -  | ○  | ●  | ●  | MANUAL: a dated restore drill in docs/                                           | M   |
| backups encrypted (backup-enc) | - | - | ● | ●  | MANUAL unless IaC shows it                                                        | S   |

## Ops

| Item (key)                     | T0 | T1 | T2 | T3 | Verify                                                                              | Fix |
|--------------------------------|----|----|----|----|-------------------------------------------------------------------------------------|-----|
| error tracking (error-track)   | -  | ○  | ●  | ●  | `d:errors`; init on client and server; `captureException` in error boundary         | S   |
| structured logging (logging)   | -  | ○  | ●  | ●  | `pino\|winston\|structlog\|getLogger\|slog\|zap`; few `console.log` in server paths | S   |
| uptime monitoring (uptime)     | -  | ○  | ●  | ●  | `[api]`: `/health` route (P/F); otherwise, and for the external pinger, MANUAL     | S   |
| alerting (alerting)            | -  | -  | ○  | ●  | MANUAL unless alert rules as code                                                   | M   |
| performance monitoring (perf)  | -  | -  | ○  | ●  | `web-vitals\|@vercel/speed-insights\|tracesSampleRate\|lhci`                        | S   |
| analytics (analytics)          | -  | -  | ○  | ●  | `d:analytics`; at least one `capture(\|track(` conversion event                     | S   |
| caching `[public-web]` (caching) | -  | -  | ○  | ●  | `Cache-Control\|revalidate\|stale-while-revalidate`; immutable static assets         | S   |
| image optimisation `[ui]` (images) | -  | -  | ○  | ●  | no raw image over 500 KB (`find . -size +500k -name '*.png' -o -name '*.jpg'`); `next/image`, `srcset`, or `loading="lazy"` | S |

## Product and UX

| Item (key)                          | T0 | T1 | T2 | T3 | Verify                                                                               | Fix |
|-------------------------------------|----|----|----|----|--------------------------------------------------------------------------------------|-----|
| 404 / 500 / empty / loading `[ui]` (states) | - | ○  | ●  | ●  | Next: `not-found.tsx error.tsx loading.tsx`; else `404.html` + error handler; `EmptyState\|No results` | S |
| accessibility `[ui]` (a11y)         | -  | ○  | ●  | ●  | `eslint-plugin-jsx-a11y\|axe-core\|@axe-core/playwright`; `alt=` and `aria-` present | M   |
| OG image + favicon `[public-web]` (og) | -  | ○  | ●  | ●  | `favicon.ico\|icon.png\|apple-touch-icon\|opengraph-image.*`; `og:image` meta        | S   |
| SEO / AEO `[public-web]` (seo)      | -  | -  | ○  | ●  | `d:robots=yes sitemap=yes`; `<meta name="description">`; `application/ld+json` on key pages | S |
| SPF / DKIM / DMARC `[email]` (email-auth) | - | ○ | ● | ● | MANUAL: DNS only; DMARC at quarantine or above                                        | S   |
| i18n readiness (i18n)               | -  | -  | ○  | ○  | strings in a locale file, not inline, when non-English markets are a goal             | L   |

## Legal and privacy

| Item (key)                              | T0 | T1 | T2 | T3 | Verify                                                                       | Fix |
|-----------------------------------------|----|----|----|----|------------------------------------------------------------------------------|-----|
| privacy policy + terms (legal-pages)    | -  | ○  | ●  | ●  | `d:privacy=yes terms=yes`; linked in footer and signup                       | S   |
| cookie consent `[analytics]` (cookies)  | -  | -  | ●  | ●  | `CookieBanner\|cookie-consent\|consent` gates analytics; EU/UK users → MANUAL | S  |
| account + data deletion `[auth]` (deletion) | - | ○ | ● | ● | `delete.*account\|deleteUser\|users\.delete\|destroy` in user routes; cascades incl. LLM logs | M |
| data export `[auth]` (export)           | -  | -  | ○  | ●  | endpoint returns the user's rows from every PII table as JSON                | M   |
| recorded terms acceptance `[auth]` (tos-accept) | - | - | ○ | ● | timestamp + terms version stored on the user                                | S   |

## Payments `[payments]` (always treated as T3 rows)

| Item (key)                          | Verify                                                                                        | Fix |
|-------------------------------------|-----------------------------------------------------------------------------------------------|-----|
| webhook idempotency (pay-idempotent) | webhook handler dedupes on event id; signature verified                                      | S   |
| receipts + refund path (pay-refund) | receipt email or page; a refund procedure in docs or code                                    | M   |
| failed-payment handling (pay-dunning) | `invoice.payment_failed` or equivalent handled; access state updated                        | M   |
| store billing for digital goods `[mobile]` (pay-store) | in-app purchases use StoreKit / Play Billing, not web checkout (store rule) | L  |

## Store review `[mobile]` at T3

| Item (key)                             | Verify / source                                                                                                   | Fix |
|----------------------------------------|-------------------------------------------------------------------------------------------------------------------|-----|
| in-app account deletion (store-deletion) | required by Apple 5.1.1(v) since June 2022 and by Play (plus a web deletion link). Code path exists and is reachable from settings. https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion · https://support.google.com/googleplay/android-developer/answer/13327111 | M |
| privacy manifest (privacy-manifest)    | `PrivacyInfo.xcprivacy` present with required-reason APIs declared. https://developer.apple.com/documentation/bundleresources/privacy-manifest-files | S |
| Sign in with Apple (siwa)              | required when any third-party login is offered (Guideline 4.8). https://developer.apple.com/app-store/review/guidelines/#login-services | M |
| store privacy forms (store-privacy)    | MANUAL: Play Data safety form, App Store privacy labels, ATT prompt if tracking                                   | S   |
| age rating + screenshots (store-meta)  | MANUAL                                                                                                            | S   |
| crash-free rate (crash-rate)           | MANUAL: ≥ 99.5% on the release candidate                                                                          | M   |
