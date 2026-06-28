# Trace Cloudflare Update Service

Phase 1 is a local scaffold for the update control plane. It does not create Cloudflare resources and does not deploy production services.

## Scope

- Worker public API decides latest release from D1 channel state.
- Downloads are gated by Worker HMAC tokens and D1 state checks.
- Phase 1 download and fallback endpoints redirect only to approved immutable GitHub tag asset URLs.
- KV is used only for revision-keyed manifest render cache: `manifest:{appId}:{platform}:{channel}:{revision}`.
- Durable Object handles coarse public rate limiting. KV is not used as a rate-limit counter.
- CI registration creates `candidate` releases only. It requires a formal release intent and fixed Android signing.
- Direct Worker admin mutation routes are disabled. Admin mutations must be added through an Access-protected Pages Functions facade or equivalent same-origin protected entry point.

## Local Commands

Run from `cloudflare/update-service/worker`:

```bash
npm install
npm run cf-typegen
npm run check
npm test
```

These are non-build validation commands. Do not run production deploys until Cloudflare account, Access, D1, KV, R2, DO, and secret values are confirmed.

## Required Secrets

Set real values with `wrangler secret put` per environment before any remote deployment:

- `DEPLOY_TOKEN_SHA256`
- `DOWNLOAD_HMAC_KEY_CURRENT`
- `DOWNLOAD_HMAC_KEY_PREVIOUS` during rotation only

The committed Wrangler config intentionally contains only non-secret settings and placeholder binding IDs.

## Phase 2 Boundary

R2 upload and streaming are not enabled in Phase 1. `RELEASES_BUCKET` is configured as a future binding, but approved GitHub tag assets remain the actual download source until Phase 2.
