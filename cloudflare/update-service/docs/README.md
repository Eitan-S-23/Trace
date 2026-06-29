# Trace Cloudflare Update Service

Phase 2 staging implements and verifies the update control plane plus R2 primary distribution path. It still does not deploy production services.

## Scope

- Worker public API decides latest release from D1 channel state.
- Downloads are gated by Worker HMAC tokens and D1 state checks.
- Primary download endpoints stream verified R2 objects when `release_assets.r2_state = 'available'`.
- GitHub fallback endpoints redirect only to approved immutable GitHub tag asset URLs after token and D1 state checks.
- KV is used only for origin/key-version/revision-keyed manifest render cache: `manifest:{origin}:{downloadKeyVersion}:{appId}:{platform}:{channel}:{revision}`.
- Durable Object handles coarse public rate limiting. KV is not used as a rate-limit counter.
- CI registration creates `candidate` releases only. It requires a formal release intent and fixed Android signing.
- Direct Worker admin mutation routes are disabled. Admin mutations are exposed through the Access-protected Pages Functions facade.
- The optional public Pages facade exposes only `/healthz` and `/api/public/*` for client networks where `workers.dev` is unreliable.

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
- `TRACE_PUBLIC_UPDATE_SERVICE_URL`
- `TRACE_DEPLOY_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_API_TOKEN`
- Fixed Android release signing secrets

Use the local config wrapper instead of adding these by hand:

```powershell
Copy-Item `
  .\cloudflare\update-service\github-actions-secrets.staging.example.json `
  .\cloudflare\update-service\.github-actions-secrets.staging.local.json

.\cloudflare\update-service\scripts\configure-github-actions-secrets.ps1 -DryRun
.\cloudflare\update-service\scripts\configure-github-actions-secrets.ps1 -Yes
```

The `.local.json` file is ignored by git. Blank values keep existing GitHub settings when the name is already present; otherwise the script fails before writing.

The workflow uses:

```text
cloudflare/update-service/scripts/build-github-release-metadata.mjs
cloudflare/update-service/scripts/upload-r2-assets.mjs
cloudflare/update-service/scripts/register-release.mjs
```

Phase 2 candidate registration uploads APK/manifest/patch assets to R2, verifies them by read-back SHA-256, writes `r2Key` and `r2Verified: true` into the metadata, and registers the candidate in D1. It does not publish the candidate to `stable` or `beta`.

`TRACE_UPDATE_SERVICE_URL` remains the Worker base URL used by CI registration (`/api/ci/releases`). `TRACE_PUBLIC_UPDATE_SERVICE_URL` is the non-secret client base URL compiled into APKs for `/api/public/latest`; in staging it should be `https://trace-update-public-staging.pages.dev`.

`upload-r2-assets.mjs` and `register-release.mjs` include bounded retries for transient network failures. Operators can tune slow staging networks with:

```text
TRACE_R2_UPLOAD_RETRIES=3
TRACE_R2_OPERATION_TIMEOUT_MS=600000
TRACE_REGISTER_RETRIES=5
TRACE_REGISTER_TIMEOUT_MS=60000
```

Existing Phase 1 releases can be backfilled into R2 without rebuilding local APKs:

```powershell
.\cloudflare\update-service\scripts\backfill-r2-release.ps1 -ReleaseTag v1.0.5 -Yes
```

The backfill script downloads existing immutable GitHub Release assets, uploads them to R2, read-back verifies SHA-256, and calls the CI registration endpoint with `r2Backfill: true`. The Worker only updates an existing release when the release tag, commit SHA, asset IDs, sizes, and SHA-256 values match D1.

For staging-only end-to-end release testing, use the one-command wrapper:

```powershell
.\cloudflare\update-service\scripts\publish-staging-release.ps1 -ReleaseTag v1.0.6 -Channels stable,beta -Yes
```

It wraps R2 backfill, D1 candidate registration, channel CAS publish, latest manifest verification, signed patch download verification, and GitHub fallback immutability checks. It does not run local build or packaging commands. The wrapper is intentionally staging-only and refuses non-staging D1 targets by default.

Staging `v1.0.5` has been backfilled and verified: all seven Android update assets are in `trace-update-staging-releases`, D1 stores `r2_state = available`, primary patch download returns `X-Trace-Asset-Source: r2`, and fallback redirects remain tag-specific GitHub Release URLs under `/releases/download/v1.0.5/...`.

Staging `v1.0.7` is published to `stable` and `beta` for current phone testing from `1.0.5 (31)`: the Linux GitHub Actions release run uploaded the APK, manifest, and seven Android patch assets to R2, read-back verified them, registered the candidate in D1, and the staging publish wrapper verified the `31 -> 33` primary patch download from R2. The matching fallback remains Worker-gated and redirects only to the immutable tag-specific GitHub Release URL under `/releases/download/v1.0.7/...`.

Staging now also has a standalone public Pages endpoint at `https://trace-update-public-staging.pages.dev`. It uses the same D1/KV/R2 state as the Worker, but signs and serves public download URLs from the Pages origin so Android clients no longer need to reach `workers.dev`.

Do not rebuild or re-upload assets for an existing release tag after clients may have installed it. If a same-tag APK was overwritten before this guard existed, old clients with the replaced APK hash may not have a matching patch and should use the full APK once. Future releases must bump `pubspec.yaml` and use a new tag.

Staging `v1.0.9` is the first release built after the public Pages split. GitHub Actions run `28383587466` built `1.0.9+35` with `TRACE_PUBLIC_UPDATE_SERVICE_URL=https://trace-update-public-staging.pages.dev`, uploaded assets to R2, registered the Cloudflare candidate, and the staging publish wrapper published it to Android `stable` and `beta`. The public Pages latest endpoint returns `v1.0.9`, and the `34 -> 35` primary patch download returns `X-Trace-Asset-Source: r2`.

Until a real `TRACE_UPDATE_PAYLOAD_ED25519_PRIVATE_KEY_BASE64` signing secret and matching client public key are configured, CI emits a staging-only placeholder `payloadSignature`. Do not publish those candidates to clients; the placeholder is intended to fail closed if accidentally exposed.

Generate payload signing keys with:

```text
cloudflare/update-service/scripts/generate-payload-signing-key.mjs
```

## Admin Facade

The Phase 1 admin facade lives in:

```text
cloudflare/update-service/admin
```

It exposes Access-protected Pages Functions under `/api/admin/*` for listing releases/channels, editing release notes, publishing to `beta`/`stable`, and disabling unpublished releases.

Direct Worker `/api/admin/*` remains disabled. Do not deploy the admin Pages project until a Cloudflare Access application is configured with issuer, audience, and email role variables.

## Required Secrets

Set real values with `wrangler secret put` per environment before any remote deployment:

- `DEPLOY_TOKEN_SHA256`
- `DOWNLOAD_HMAC_KEY_CURRENT`
- `DOWNLOAD_HMAC_KEY_PREVIOUS` during rotation only

The committed Wrangler config intentionally contains only non-secret settings and placeholder binding IDs.

## Phase 3 Boundary

The current admin UI is a lightweight static operator surface. The fuller React console, R2 retention cleanup UI, backup controls, manifest preview polish, and lightweight statistics remain Phase 3+ work.
