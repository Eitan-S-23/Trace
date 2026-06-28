# Trace Update Admin

Phase 1 provides an Access-protected Pages Functions admin facade. The full React UI is still deferred until the Worker+D1 control plane is verified end-to-end.

No direct admin mutation route is exposed on the standalone Worker. During the no-custom-domain phase, mutations go through this Pages Functions same-origin facade.

## Current API

- `GET /api/admin/session`
- `GET /api/admin/channels?appId=trace&platform=android`
- `GET /api/admin/releases?appId=trace&platform=android`
- `POST /api/admin/channels/:channel/publish`
- `POST /api/admin/releases/:releaseId/notes`
- `POST /api/admin/releases/:releaseId/disable`

`stable` publish/rollback and disable require `owner`. `beta` publish/rollback and release note edits require `publisher` or `owner`. Read-only endpoints allow `viewer`.

Every mutation requires:

- A valid Cloudflare Access JWT in `CF-Access-Jwt-Assertion`.
- The Access JWT issuer, audience, expiry, signature, and email allowlist to verify.
- Same-origin `Origin`.
- `X-CSRF-Token` matching the `trace_admin_csrf` cookie from `GET /api/admin/session`.

## Required Configuration

Configure these Pages variables before deployment:

```text
ACCESS_JWT_ISSUER=https://<team-name>.cloudflareaccess.com
ACCESS_JWT_AUD=<Access application AUD tag>
ADMIN_VIEWER_EMAILS=<comma-separated emails>
ADMIN_PUBLISHER_EMAILS=<comma-separated emails>
ADMIN_OWNER_EMAILS=<comma-separated emails>
ADMIN_ALLOWED_ORIGINS=<optional comma-separated extra origins>
```

The committed `wrangler.jsonc` intentionally leaves Access values empty so the facade fails closed until Access is configured.

## Local Checks

```powershell
Set-Location D:\github\my\bluetooth_flutter_Trace\cloudflare\update-service\admin
npm ci
npm run check
```

These are non-build checks.
