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

## Staging Bootstrap

Use the staging guide when you are ready to create real Cloudflare staging resources:

```text
cloudflare/update-service/docs/STAGING-SETUP.md
```

The bootstrap scripts are:

```text
cloudflare/update-service/scripts/bootstrap-staging.ps1
cloudflare/update-service/scripts/bootstrap-staging.mjs
```

They are staging-only and require an explicit `-Yes` / `--yes` flag before creating Cloudflare resources or deploying the Worker.

## GitHub Release Candidate Registration

Formal GitHub Releases now register an Android Cloudflare `candidate` after release assets are uploaded. This only runs for `v*` tag builds or `workflow_dispatch publish_release=true`; ordinary push builds still cannot register candidates.

The GitHub repository must define:

- `TRACE_UPDATE_SERVICE_URL`
- `TRACE_DEPLOY_TOKEN`
- Fixed Android release signing secrets

The workflow uses:

```text
cloudflare/update-service/scripts/build-github-release-metadata.mjs
cloudflare/update-service/scripts/register-release.mjs
```

Phase 1 candidate registration still uses immutable GitHub tag asset URLs as the download source. It does not publish the candidate to `stable` or `beta`.

Until a real `TRACE_UPDATE_PAYLOAD_ED25519_PRIVATE_KEY_BASE64` signing secret and matching client public key are configured, CI emits a staging-only placeholder `payloadSignature`. Do not publish those candidates to clients; the placeholder is intended to fail closed if accidentally exposed.

## Required Secrets

Set real values with `wrangler secret put` per environment before any remote deployment:

- `DEPLOY_TOKEN_SHA256`
- `DOWNLOAD_HMAC_KEY_CURRENT`
- `DOWNLOAD_HMAC_KEY_PREVIOUS` during rotation only

The committed Wrangler config intentionally contains only non-secret settings and placeholder binding IDs.

## Phase 2 Boundary

R2 upload and streaming are not enabled in Phase 1. `RELEASES_BUCKET` is configured as a future binding, but approved GitHub tag assets remain the actual download source until Phase 2.
