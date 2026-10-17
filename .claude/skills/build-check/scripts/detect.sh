#!/usr/bin/env bash
# build-check feature detection. Read-only; run from repo root; prints one line of key=value pairs.
set -u
SKIP="node_modules .git dist build vendor .next .nuxt .svelte-kit .venv venv __pycache__ target Pods DerivedData coverage .turbo"
PR=""; for s in $SKIP; do PR="$PR -name $s -o"; done; PR="${PR% -o}"
XD=""; for s in $SKIP; do XD="$XD --exclude-dir=$s"; done
f() { find . \( $PR \) -prune -o -type f \( "$@" \) -print 2>/dev/null | head -1 | grep -q .; }  # any file
d() { find . \( $PR \) -prune -o -type d \( "$@" \) -print 2>/dev/null | head -1 | grep -q .; }  # any dir
# --- dependency surface: direct-dep manifests only (lockfiles would pull in transitive deps) ---
MAN=$(cat package.json app.json requirements*.txt pyproject.toml Pipfile go.mod Gemfile pubspec.yaml \
  Package.swift Podfile build.gradle build.gradle.kts app/build.gradle app/build.gradle.kts Cargo.toml 2>/dev/null)
m() { printf '%s' "$MAN" | grep -qiE -- "$1"; }
# --- one pass over source for SDK/import tokens (cheap: -o keeps only matched words) ---
P_AUTH='next-auth|@auth/core|better-auth|@clerk/|[^a-z]lucia[^a-z]|passport|devise|jsonwebtoken|pyjwt|python-jose|django\.contrib\.auth|firebase/auth|firebase_auth|supabase[^;]{0,40}\.auth\.|@supabase/ssr|auth0|@kinde'
P_DB='prisma|drizzle|@neondatabase|@vercel/postgres|[^a-z]pg[^a-z]|postgres|psycopg|asyncpg|mysql2|sqlalchemy|better-sqlite3|sqlite|mongoose|mongodb|pymongo|@supabase/supabase-js|firestore|firebase-admin|[^a-z]redis[^a-z]|[^a-z]convex[^a-z]'
P_LLM='@anthropic-ai/sdk|[^a-z]anthropic[^a-z]|[^a-z]openai[^a-z]|@ai-sdk/|from .ai.|langchain|llamaindex|ollama|@google/generative-ai|@google/genai|google-generativeai|[^a-z]gemini[^a-z]|bedrock-runtime|groq-sdk|mistralai|[^a-z]cohere[^a-z]'
P_PAY='stripe|@paddle|paddle-js|lemonsqueezy|react-native-purchases|purchases_flutter|revenuecat|StoreKit|billingclient|paypal'
P_MAIL='[^a-z]resend[^a-z]|@sendgrid|sendgrid|postmark|nodemailer|client-ses|ses_client|mailgun|EMAIL_BACKEND|mailersend|loops\.so|brevo'
P_UP='multer|formidable|busboy|uploadthing|@vercel/blob|client-s3|multipart/form-data|django\.core\.files|ActiveStorage|carrierwave'
P_CLOUD='@aws-sdk|boto3|@google-cloud|twilio|mapbox|@googlemaps|@azure/|cloudinary|algoliasearch|pinecone|@upstash'
P_OBS='@sentry|sentry_sdk|sentry-ruby|posthog|plausible|googletagmanager|gtag\(|@vercel/analytics|mixpanel|[^a-z]amplitude[^a-z]|bugsnag|[^a-z]rollbar|datadog|logrocket|highlight\.run'
TOK=$(grep -rIhoiE $XD --include=*.{js,jsx,ts,tsx,mjs,cjs,py,go,rb,swift,kt,kts,dart,java,html,toml,yml,yaml,json,xml,gradle,plist} \
  -e "$P_AUTH|$P_DB|$P_LLM|$P_PAY|$P_MAIL|$P_OBS|$P_UP|$P_CLOUD" . 2>/dev/null | sort -u)
t() { printf '%s\n' "$TOK" | grep -qiE -- "$1"; }
any() { m "$1" || t "$1"; }
pick() { local v=$1 out=""; shift; for kv in "$@"; do any "${kv#*=}" && out="$out,${kv%%=*}"; done; out="${out#,}"; printf '%s=%s ' "$v" "${out:-no}"; }
ex() { for x in "$@"; do [ -e "$x" ] && return 0; done; return 1; }  # any path exists (globs ok)
yn() { printf '%s=%s ' "$1" "${2:-no}"; }

# --- stack ---
S=""
m '"expo"|expo-' && S=expo
[ -z "$S" ] && m '"react-native"' && S=react-native
[ -z "$S" ] && { m '"next"' || ex next.config.*; } && S=nextjs
[ -z "$S" ] && m '"nuxt"' && S=nuxt
[ -z "$S" ] && m '@remix-run|@sveltejs/kit|"astro"' && S=js-metaframework
[ -z "$S" ] && ex vite.config.* && S=vite
[ -z "$S" ] && m '"react"' && S=react
[ -z "$S" ] && m '"express"|"fastify"|"hono"|"koa"' && S=node-server
[ -z "$S" ] && [ -f manage.py ] && S=django
[ -z "$S" ] && m 'fastapi' && S=fastapi
[ -z "$S" ] && m '^flask|"flask|flask[>=~ ]' && S=flask
[ -z "$S" ] && { m '^rails|gem .rails' || [ -f config/routes.rb ]; } && S=rails
[ -z "$S" ] && grep -qs '^  flutter:' pubspec.yaml && S=flutter
[ -z "$S" ] && { ex *.xcodeproj *.xcworkspace || [ -f Package.swift ]; } && S=swift
[ -z "$S" ] && { f -name AndroidManifest.xml || ex build.gradle*; } && S=kotlin-android
[ -z "$S" ] && [ -f go.mod ] && S=go
[ -z "$S" ] && [ -f Cargo.toml ] && S=rust
[ -z "$S" ] && [ -f package.json ] && S=node
[ -z "$S" ] && ex requirements*.txt pyproject.toml Pipfile && S=python
[ -z "$S" ] && ex index.html public/index.html && S=static-html
printf 'stack=%s ' "${S:-unknown}"
case "$S" in expo|react-native|flutter|swift|kotlin-android) printf 'mobile=%s ' "$S";; *) printf 'mobile=no ';; esac
case "$S" in static-html) printf 'static=yes ';; *) printf 'static=no ';; esac

# --- shape flags (checklist tags: [deps] [api] [ui] [public-web] [uploads] [metered]) ---
[ -n "$MAN" ] && yn deps yes || yn deps no
API=no; case "$S" in nextjs|nuxt|js-metaframework|node-server|django|fastapi|flask|rails|go|rust) API=yes;; esac
[ "$API" = no ] && { d -name api -o -name server -o -name functions -o -name routes -o -name controllers; } && API=yes
yn api "$API"
UI=no; case "$S" in static-html|vite|react|nextjs|nuxt|js-metaframework|expo|react-native|flutter|swift|kotlin-android) UI=yes;; esac
[ "$UI" = no ] && f -name '*.html' -o -name '*.tsx' -o -name '*.jsx' -o -name '*.vue' -o -name '*.svelte' && UI=yes
yn ui "$UI"
case "$S" in expo|react-native|flutter|swift|kotlin-android) yn public_web no;; *) yn public_web "$UI";; esac

# --- features (empty value => none detected) ---
pick auth next-auth='next-auth|@auth/core' better-auth=better-auth clerk='@clerk/' lucia='[^a-z]lucia[^a-z]' passport=passport devise=devise \
  supabase-auth='@supabase/ssr|supabase[^;]{0,40}\.auth\.' firebase-auth='firebase/auth|firebase_auth' django-auth='django\.contrib\.auth' \
  auth0=auth0 kinde=@kinde jwt='jsonwebtoken|pyjwt|python-jose'
pick db prisma=prisma drizzle=drizzle postgres='@neondatabase|@vercel/postgres|[^a-z]pg[^a-z]|postgres|psycopg|asyncpg' mysql=mysql2 \
  sqlite='better-sqlite3|sqlite' mongo='mongoose|mongodb|pymongo' supabase='@supabase/supabase-js' firebase='firestore|firebase-admin' redis='[^a-z]redis[^a-z]' convex='[^a-z]convex[^a-z]'
pick llm anthropic='@anthropic-ai/sdk|[^a-z]anthropic[^a-z]' openai='[^a-z]openai[^a-z]' ai-sdk='@ai-sdk/|"ai":' langchain=langchain llamaindex=llamaindex \
  ollama=ollama gemini='@google/generative-ai|@google/genai|google-generativeai|[^a-z]gemini[^a-z]' bedrock=bedrock-runtime groq=groq-sdk mistral=mistralai cohere='[^a-z]cohere[^a-z]'
pick payments stripe=stripe paddle='@paddle|paddle-js' lemonsqueezy=lemonsqueezy revenuecat='react-native-purchases|purchases_flutter|revenuecat' storekit=StoreKit play-billing=billingclient paypal=paypal
pick email resend='[^a-z]resend[^a-z]' sendgrid=sendgrid postmark=postmark nodemailer=nodemailer ses='client-ses|ses_client' mailgun=mailgun django-mail=EMAIL_BACKEND loops='loops\.so' brevo=brevo
pick errors sentry='@sentry|sentry_sdk|sentry-ruby' bugsnag=bugsnag rollbar='[^a-z]rollbar' datadog=datadog highlight='highlight\.run'
pick analytics posthog=posthog plausible=plausible ga='googletagmanager|gtag\(' vercel='@vercel/analytics' mixpanel=mixpanel amplitude='[^a-z]amplitude[^a-z]' logrocket=logrocket

UP=no; any "$P_UP" && UP=yes; yn uploads "$UP"
MET=no; { any "$P_LLM" || any "$P_CLOUD"; } && MET=yes; yn metered "$MET"
# --- repo hygiene ---
CI=""; ex .github/workflows/*.yml .github/workflows/*.yaml && CI=github-actions
[ -f .gitlab-ci.yml ] && CI="$CI,gitlab"; [ -f .circleci/config.yml ] && CI="$CI,circleci"
[ -f bitbucket-pipelines.yml ] && CI="$CI,bitbucket"; [ -f Jenkinsfile ] && CI="$CI,jenkins"; yn ci "${CI#,}"
DEP=""; for p in vercel.json:vercel netlify.toml:netlify fly.toml:fly render.yaml:render Dockerfile:docker app.yaml:gae eas.json:eas fastlane:fastlane; do [ -e "${p%%:*}" ] && DEP="$DEP,${p#*:}"; done; yn deploy "${DEP#,}"
T=""
{ m '"vitest"' || ex vitest.config.*; } && T="$T,vitest"
{ m '"jest"' || ex jest.config.*; } && T="$T,jest"
{ m '@playwright/test' || ex playwright.config.*; } && T="$T,playwright"
m '"cypress"' && T="$T,cypress"
{ [ -f pytest.ini ] || [ -f conftest.py ] || grep -qs 'tool.pytest' pyproject.toml || m '^pytest'; } && T="$T,pytest"
f -name '*_test.go' && T="$T,go-test"; { [ -d spec ] && m 'rspec'; } && T="$T,rspec"
f -name '*_test.dart' && T="$T,flutter-test"; d -iname '*Tests' -o -iname '*UITests' && [ "$S" = swift ] && T="$T,xctest"
f -name '*.test.*' -o -name '*.spec.*' -o -name 'test_*.py' && T="$T,unit-files"
d -name test -o -name tests -o -name __tests__ -o -name spec -o -name e2e && T="$T,test-dir"
yn tests "${T#,}"
L=$(ls package-lock.json yarn.lock pnpm-lock.yaml bun.lockb bun.lock poetry.lock uv.lock Pipfile.lock go.sum Gemfile.lock Podfile.lock pubspec.lock Cargo.lock 2>/dev/null | tr '\n' ',')
yn lockfile "${L%,}"
# --- secrets (SUSPECT = needs human eyes, not proof) ---
SEC=""
for e in .env .env.local .env.production .env.development; do
  [ -f "$e" ] && ! grep -qsE "^\s*\.env|^\s*\*\.env|^\s*${e//./\\.}" .gitignore && SEC="$SEC,$e-unignored"
done
f -name '.env' -o -name '.env.*' ! -name '.env.example' ! -name '.env.sample' ! -name '.env.template' && [ ! -f .gitignore ] && SEC="$SEC,env-no-gitignore"
HITS=$(grep -rIlE $XD --exclude='*.lock' --exclude='*-lock.*' --exclude='.env.example' --exclude='*.md' \
  -e 'sk-(ant-|proj-|live_)?[A-Za-z0-9_-]{20,}|sk_live_[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{36}|AIza[0-9A-Za-z_-]{35}|xox[bap]-[0-9A-Za-z-]{10,}|SG\.[A-Za-z0-9_-]{22}\.' . 2>/dev/null | head -5 | tr '\n' ',')
[ -n "$HITS" ] && SEC="$SEC,hardcoded:${HITS%,}"
[ -n "$SEC" ] && printf 'secrets_in_repo=SUSPECT(%s) ' "${SEC#,}" || printf 'secrets_in_repo=clean '
# --- SEO / legal / docs ---
R=no; f -name robots.txt -o -name 'robots.ts' -o -name 'robots.js' && R=yes
SM=no; f -name 'sitemap*.xml' -o -name 'sitemap.ts' -o -name 'sitemap.js' -o -name 'next-sitemap.config.*' -o -name 'sitemap*.xml.gz' && SM=yes
printf 'robots=%s sitemap=%s ' "$R" "$SM"
PV=no; { f -iname '*privacy*' || d -iname '*privacy*' || grep -rIqiE $XD -e 'href=["'"'"']/?privacy|path:\s*["'"'"']/?privacy' . 2>/dev/null; } && PV=yes
TM=no; { f -iname '*terms*' -o -iname '*tos.*' || d -iname 'terms*' || grep -rIqiE $XD -e 'href=["'"'"']/?terms|path:\s*["'"'"']/?terms' . 2>/dev/null; } && TM=yes
printf 'privacy=%s terms=%s ' "$PV" "$TM"
yn readme "$(ls README* readme* 2>/dev/null | head -1)"
yn license "$(ls LICENSE* LICENCE* 2>/dev/null | head -1)"
echo
