# Cloudflare Staging Setup

This guide turns the Phase 1 Cloudflare update-service scaffold into a real staging deployment. It intentionally does not create or deploy production resources.

## What The Script Does

`scripts/bootstrap-staging.mjs` automates the safe staging-only steps:

- Creates or reuses the D1 database `trace-update-staging`.
- Creates or reuses the KV namespace `trace-update-staging-manifest-cache`.
- Creates or reuses the R2 bucket `trace-update-staging-releases`.
- Writes the real staging D1/KV/R2 resource IDs into `worker/wrangler.jsonc`.
- Applies D1 migrations to staging.
- Deploys the staging Worker.
- Writes Worker secrets:
  - `DEPLOY_TOKEN_SHA256`
  - `DOWNLOAD_HMAC_KEY_CURRENT`
- Calls `/healthz` and `/api/public/latest` as smoke tests.
- Prints the GitHub Secrets needed later for CI candidate registration.

The script refuses `prod`. Production must be a separate, explicit step after staging is verified.

## What Still Needs Human Confirmation

These cannot be safely automated without account-specific decisions:

- Creating the Cloudflare API token in your account.
- Deciding who can access the future Pages admin console.
- Creating the Cloudflare Access application for the future admin UI.
- Enabling the client app to use the staging Worker URL in a GitHub Actions build.
- Promoting any release to stable or production.

Direct Worker admin mutations remain disabled by design. `/api/admin/*` should return 503 until the Access-protected Pages Functions facade is implemented.

## Prerequisites

- Node.js 24 or compatible modern Node.js with built-in `fetch`.
- Cloudflare account access.
- A Cloudflare API token with account-level permissions for:
  - Workers Scripts: Edit
  - D1: Edit
  - Workers KV Storage: Edit
  - R2: Edit
- The repo checked out locally.
- No local Flutter, Gradle, Xcode, Dart compile, or package build commands are needed.

Install Worker dependencies first:

```powershell
Set-Location D:\github\my\bluetooth_flutter_Trace\cloudflare\update-service\worker
npm ci
npm run check
Set-Location D:\github\my\bluetooth_flutter_Trace
```

`npm test` is expected to fail on this Windows host if local workerd still crashes with `0xc0000005`. The Linux GitHub Actions invariant test is the authoritative runtime check for now.

## Step 1: Create The Cloudflare API Token

In Cloudflare Dashboard:

1. Open `My Profile` -> `API Tokens`.
2. Create a custom token.
3. Add the account permissions listed in prerequisites.
4. Scope it to your account.
5. Copy the token once.

Do not commit the token. Set it only in your shell:

```powershell
$env:CLOUDFLARE_ACCOUNT_ID = "your-account-id"
$env:CLOUDFLARE_API_TOKEN = "your-api-token"
```

## Step 2: Preview The Bootstrap Plan

Run without `-Yes` first. It prints the plan and does nothing remotely:

```powershell
.\cloudflare\update-service\scripts\bootstrap-staging.ps1
```

Optional dry-run form:

```powershell
.\cloudflare\update-service\scripts\bootstrap-staging.ps1 -DryRun
```

Expected plan:

- Environment is `staging`.
- D1 database is `trace-update-staging`.
- KV namespace is `trace-update-staging-manifest-cache`.
- R2 bucket is `trace-update-staging-releases`.
- Deploy target is `trace-update-service-staging`.

## Step 3: Run The Staging Bootstrap

Run:

```powershell
.\cloudflare\update-service\scripts\bootstrap-staging.ps1 -Yes
```

Optional: write a local JSON summary to an ignored path:

```powershell
.\cloudflare\update-service\scripts\bootstrap-staging.ps1 -Yes -Output cloudflare/update-service/.bootstrap/staging-summary.json
```

The output includes:

- Worker URL.
- D1 database ID.
- KV namespace ID.
- R2 bucket name.
- `TRACE_UPDATE_SERVICE_URL` for future GitHub Secrets.
- `TRACE_DEPLOY_TOKEN` for future GitHub Secrets.

Do not commit `TRACE_DEPLOY_TOKEN`. The Worker stores only `DEPLOY_TOKEN_SHA256`.

## Step 4: Confirm The Local Config Diff

The script updates only non-secret resource IDs in:

```text
cloudflare/update-service/worker/wrangler.jsonc
```

Check:

```powershell
git diff -- cloudflare/update-service/worker/wrangler.jsonc
```

Expected staging changes:

- `env.staging.d1_databases[0].database_id` is no longer the placeholder UUID.
- `env.staging.kv_namespaces[0].id` is no longer the placeholder ID.
- `env.staging.r2_buckets[0].bucket_name` is `trace-update-staging-releases` or your override.

Do not copy staging IDs into `prod`.

## Step 5: Manual Smoke Checks

If the script prints a Worker URL, test it:

```powershell
$worker = "https://your-staging-worker.workers.dev"
Invoke-RestMethod "$worker/healthz"
Invoke-RestMethod "$worker/api/public/latest?appId=trace&platform=android&channel=stable&versionCode=1&schemaVersion=2&capabilities=patch,full,payloadSignature"
```

Expected:

- `/healthz` returns `ok: true`, service name, and `environment: staging`.
- `/api/public/latest` returns `errorCode: NO_UPDATE` until a candidate is registered and manually published.
- If the bootstrap script warns that Node smoke checks were inconclusive, but these PowerShell checks succeed, the staging deployment itself is healthy. This can happen when local Node `fetch` is affected by proxy or network settings.

Confirm migrations:

```powershell
Set-Location D:\github\my\bluetooth_flutter_Trace\cloudflare\update-service\worker
npx wrangler d1 migrations list trace-update-staging --env staging --remote
Set-Location D:\github\my\bluetooth_flutter_Trace
```

Confirm secrets exist without revealing values:

```powershell
Set-Location D:\github\my\bluetooth_flutter_Trace\cloudflare\update-service\worker
npx wrangler secret list --env staging
Set-Location D:\github\my\bluetooth_flutter_Trace
```

Expected secret names:

- `DEPLOY_TOKEN_SHA256`
- `DOWNLOAD_HMAC_KEY_CURRENT`

## Step 6: GitHub Secrets For CI Registration

After bootstrap, add these repository secrets in GitHub:

```text
TRACE_UPDATE_SERVICE_URL=<printed staging Worker URL>
TRACE_DEPLOY_TOKEN=<printed raw deploy token>
```

These are not enough to publish production updates. They allow the formal GitHub Release job to call staging `/api/ci/releases` and create a D1 `candidate`.

Phase 1 still uses immutable GitHub tag asset URLs as the file source. R2 upload and R2 primary downloads are Phase 2.

## Step 7: Configure Payload Signing For Client-Visible Updates

Generate an Ed25519 signing key pair:

```powershell
node .\cloudflare\update-service\scripts\generate-payload-signing-key.mjs
```

The script prints:

```text
TRACE_UPDATE_PAYLOAD_KEY_VERSION=<key-version>
TRACE_UPDATE_PAYLOAD_ED25519_PRIVATE_KEY_BASE64=<pkcs8-der-private-key>
TRACE_UPDATE_PAYLOAD_ED25519_PUBLIC_KEY_BASE64=<raw-32-byte-public-key>
```

Add the private key and public key as GitHub repository secrets:

```text
TRACE_UPDATE_PAYLOAD_ED25519_PRIVATE_KEY_BASE64
TRACE_UPDATE_PAYLOAD_ED25519_PUBLIC_KEY_BASE64
```

Add the key version as a GitHub repository variable:

```text
TRACE_UPDATE_PAYLOAD_KEY_VERSION
```

Do not publish Cloudflare candidates to phones until these are configured. Without the signing secrets, CI uses a staging-only placeholder `payloadSignature` that is intended to fail closed in clients.

## Step 8: Client Activation Boundary

The Android client only uses Cloudflare primary when the app build includes:

```text
TRACE_CLOUDFLARE_UPDATE_MANIFEST_URL=https://your-staging-worker.workers.dev/api/public/latest
```

Do not run local Flutter builds. Wire this into GitHub Actions only after staging Worker checks pass and you intentionally want a Cloudflare-capable artifact.

Before enabling this for normal users:

- Keep GitHub latest pointing only to a manually approved stable release.
- Verify old clients are still safe.
- Verify the Cloudflare manifest returns v1-compatible output for clients without `schemaVersion` and `capabilities`.

## Step 9: Verify Candidate Registration

After the GitHub Secrets are configured and the CI workflow changes are pushed, trigger a formal test release from GitHub Actions:

```text
workflow_dispatch:
  publish_release: true
  release_tag: v<next-version>
```

Expected result:

- GitHub Actions creates or updates the tag-specific GitHub Release.
- The release job uploads `ble-monitor-android.apk`, `ble-monitor-update.json`, and any `.tpatch` files.
- `build-github-release-metadata.mjs` creates local CI metadata from those assets.
- `register-release.mjs` calls staging `/api/ci/releases`.
- D1 stores the release as `candidate`.

The public latest endpoint should still return `NO_UPDATE` until an Access-protected admin facade publishes that candidate to `stable` or `beta`:

```powershell
$worker = "https://your-staging-worker.workers.dev"
Invoke-RestMethod "$worker/api/public/latest?appId=trace&platform=android&channel=stable&versionCode=1&schemaVersion=2&capabilities=patch,full,payloadSignature"
```

Current Phase 1 registration allows a staging-only placeholder `payloadSignature` when no real payload signing key is configured. Do not publish those candidates to clients. Configure real Ed25519 payload signing before using Cloudflare latest for production updates.

## Step 10: Configure Access-Protected Admin Facade

The Phase 1 admin facade lives in:

```text
cloudflare/update-service/admin
```

Before deploying it, create a Cloudflare Access application for the Pages project URL and collect:

```text
ACCESS_JWT_ISSUER=https://<team-name>.cloudflareaccess.com
ACCESS_JWT_AUD=<Access application AUD tag>
```

Configure Pages variables for the admin project:

```text
ACCESS_JWT_ISSUER
ACCESS_JWT_AUD
ADMIN_VIEWER_EMAILS
ADMIN_PUBLISHER_EMAILS
ADMIN_OWNER_EMAILS
ADMIN_ALLOWED_ORIGINS
```

At least your email must be in `ADMIN_OWNER_EMAILS` for stable publish, rollback, and disable operations. The facade fails closed while `ACCESS_JWT_ISSUER` or `ACCESS_JWT_AUD` is empty.

Run local non-build checks:

```powershell
Set-Location D:\github\my\bluetooth_flutter_Trace\cloudflare\update-service\admin
npm ci
npm run check
Set-Location D:\github\my\bluetooth_flutter_Trace
```

Deploy the staging Pages project only after Access is configured:

```powershell
Set-Location D:\github\my\bluetooth_flutter_Trace\cloudflare\update-service\admin
npx wrangler pages deploy .\public --project-name trace-update-admin-staging
Set-Location D:\github\my\bluetooth_flutter_Trace
```

Then protect the resulting Pages URL with the Access application before using mutation endpoints.

## Step 11: Publish A Candidate To Beta

Open the protected Pages URL in a browser first so Cloudflare Access sets the session. Call:

```text
GET /api/admin/session
GET /api/admin/channels?appId=trace&platform=android
GET /api/admin/releases?appId=trace&platform=android
```

Use the `csrfToken` from `/api/admin/session`, the current `beta` channel `revision`, and the target `releaseId`:

```text
POST /api/admin/channels/beta/publish
{
  "appId": "trace",
  "platform": "android",
  "releaseId": "<candidate release id>",
  "expectedRevision": <current beta revision>,
  "rollback": false
}
```

Expected result:

- The API returns `{ "ok": true, "revision": <new revision> }`.
- D1 `channels.beta.current_release_id` points to the candidate.
- `/api/public/latest?...channel=beta...` returns an update manifest for clients below the target `versionCode`.

Do not publish to `stable` until beta verification succeeds on a real phone.

## Failure Handling

If resource creation fails:

- Verify `CLOUDFLARE_ACCOUNT_ID`.
- Verify token permissions.
- Re-run the script. It is idempotent and reuses resources with the same names.

If `wrangler deploy --env staging` fails:

- Run `npm ci` in `cloudflare/update-service/worker`.
- Run `npm run check`.
- Re-run bootstrap with `-SkipMigrations` if migrations already applied.

If smoke tests cannot infer the Worker URL:

```powershell
$env:TRACE_CF_STAGING_WORKER_URL = "https://your-staging-worker.workers.dev"
.\cloudflare\update-service\scripts\bootstrap-staging.ps1 -Yes -SkipDeploy -SkipMigrations -SkipSecrets
```

If the deploy token was lost:

```powershell
$env:TRACE_DEPLOY_TOKEN = "new-random-token"
.\cloudflare\update-service\scripts\bootstrap-staging.ps1 -Yes -SkipDeploy -SkipMigrations -SkipSmoke
```

Then update GitHub secret `TRACE_DEPLOY_TOKEN`.

## Cleanup

Only clean up staging if you no longer need it. Use Cloudflare Dashboard, or run Wrangler/API commands manually after confirming names:

```powershell
Set-Location D:\github\my\bluetooth_flutter_Trace\cloudflare\update-service\worker
npx wrangler delete --env staging
npx wrangler d1 delete trace-update-staging
npx wrangler kv namespace delete --namespace-id <staging-kv-id>
npx wrangler r2 bucket delete trace-update-staging-releases
Set-Location D:\github\my\bluetooth_flutter_Trace
```

Do not run cleanup commands against `prod`.

## Script Reference

PowerShell wrapper:

```powershell
.\cloudflare\update-service\scripts\bootstrap-staging.ps1 -Yes
```

Node script:

```powershell
node .\cloudflare\update-service\scripts\bootstrap-staging.mjs --yes
```

Useful options:

```text
--dry-run
--skip-deploy
--skip-secrets
--skip-migrations
--skip-smoke
--output <path>
```

Useful environment overrides:

```text
TRACE_DEPLOY_TOKEN
TRACE_DOWNLOAD_HMAC_KEY_CURRENT
TRACE_CF_STAGING_WORKER_URL
TRACE_CF_STAGING_D1_NAME
TRACE_CF_STAGING_KV_TITLE
TRACE_CF_STAGING_R2_BUCKET
```
