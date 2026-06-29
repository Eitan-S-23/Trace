# Plan Review Log: Cloudflare 更新后台与分发系统

Act 1 (grill) complete — plan locked with the user. MAX_ROUNDS=5.

## Act 1 Summary

Locked decisions:

- GitHub Actions remains the build factory.
- Cloudflare Workers + D1 + R2 + KV + Pages becomes the update control plane and primary distribution path.
- GitHub Release remains as full-history backup and fallback.
- D1 remains the source of truth; PostgreSQL was explicitly rejected for zero-cost goals.
- R2 stores only recent hot release assets, with GitHub Release holding full history.
- Cloudflare Access protects the admin console and admin API.
- CI uses a separate `DEPLOY_TOKEN`.
- Public manifest stays unauthenticated; downloads use short-lived signed URLs, D1 allow-list checks, caching, and Cloudflare rate limiting.
- Android keeps incremental updates first and adds full APK fallback.
- Windows app self-update is out of scope for v1.
- Admin UI is Cloudflare Pages with Vite + React + TypeScript.
- Worker API is Hono + TypeScript using D1 prepared statements and no ORM.

## Act 2 Status

Round 1 complete — manual Codex review supplied by user. Material findings require revision.

## Round 1 — Codex (manual)

VERDICT: REVISE.

Key findings:

- GitHub fallback bypasses Cloudflare disable/rollback controls if direct URLs or `/latest/download` are used.
- KV invalidation cannot be treated as immediate; rollback/disable can serve stale manifests and signed URLs.
- `workers.dev` plus WAF/Rate Limiting is a weak assumption without a custom zone.
- Current Android client only understands the existing GitHub v1 manifest and GitHub-derived patch URLs.
- D1 schema was only table names and lacked constraints, indexes, transactions, and race guards.
- `channels.current_release_id` cannot be protected from disabled releases with a plain foreign key.
- Release status was denormalized and race-prone across stable/beta and platforms.
- Publish/rollback/disable lacked compare-and-swap or channel revision semantics.
- CI upload/register had partial failure risks and needed idempotency and artifact verification.
- Current GitHub Actions creates releases on every push, which is too broad for Cloudflare candidate registration.
- Android full fallback must require fixed release signing before publication.
- Signed download tokens, cache-control, Access validation, CSRF/CORS, secret rotation, and emergency stop were underspecified.
- D1 backup and observability were too weak.
- A safer implementation sequence is to first put Worker+D1 in front of GitHub tag assets, then move hot assets to R2.
- Manifest signing, patch parser limits, full APK temp-file cleanup, and minimum client compatibility were missing.
- Windows assets need platform-specific publication rules.

### Codex response / plan revision

Accepted and revised `CF-UPDATE-BACKEND-PLAN.md`:

- GitHub fallback is no longer direct. Fallback must go through a Worker endpoint that checks D1 release/asset/channel state and redirects only to immutable tag-specific GitHub assets. `/latest/download` is explicitly disallowed.
- Added phased rollout: Phase 0 fixed signing and compatible client, Phase 1 Worker+D1 control plane over GitHub tag assets, Phase 2 R2 primary downloads, Phase 3 admin console polish.
- KV is no longer the channel source of truth. Channel revision lives in D1; KV only caches manifest render output keyed by revision. Downloads always re-check D1 state.
- Added Worker-side coarse rate limiting for `workers.dev`; zone-level WAF/Rate Limiting is deferred until a custom domain exists.
- Added Manifest v2 compatibility fields, `minClientVersionCode`, capabilities, signed release payloads, and static signed emergency manifest.
- Added D1 migration requirements: foreign keys, CHECK constraints, UNIQUE constraints, lookup indexes, and foreign key enforcement.
- Reworked release status: only `candidate`/`disabled` is stored; `published` and `superseded` are derived from channel references and history.
- Added channel revision compare-and-swap semantics for publish/rollback/disable.
- Added CI idempotency by release tag/run id/commit, R2 HEAD and sha256 verification, and candidate registration only for tags or explicit workflow dispatch publish.
- Made fixed Android release signing a hard prerequisite before Cloudflare candidate publication.
- Added signed token fields: method, assetId, releaseId, expiry, keyVersion, HMAC signature.
- Added strict Access JWT verification, Origin/CORS/CSRF handling, hashed CI token storage, and future GitHub OIDC preference.
- Added manifest/download cache-control requirements.
- Added patch parser safety limits and full APK unique temp-file cleanup.
- Added per-platform channel modeling so Windows asset state cannot pollute Android release eligibility.
- Added append-only audit logs, health/integrity checks, request IDs, basic alert states, minimal scheduled D1 export backup, and secret rotation.
- Added R2 retention guard: rollback to archived/R2-deleted releases is blocked unless assets are restored and checksum-verified or explicitly fallback-only.

Rejected or deferred:

- Full custom domain requirement is deferred because the user currently has no domain. The plan now treats WAF/Rate Limiting as a future custom-domain enhancement and uses Worker-side coarse throttling for v1.
- Full PostgreSQL or external database alternatives remain rejected due to zero-cost goal.

## Round 2 — Codex (manual)

VERDICT: REVISE.

Key findings:

- Manifest signing conflicted with editable release notes: CI signed `releaseNotes`, but admin could edit them before publish.
- Admin Access on separate `*.workers.dev` / `*.pages.dev` origins was not proven; Worker API would not automatically receive Pages Access context.
- Old clients would still fetch GitHub `/latest/download`, while current workflow creates releases on ordinary pushes.
- Release flow contradicted phased rollout because Phase 1 claimed GitHub tag assets first, but the flow required R2 upload before registration.
- Rollback and `superseded` derivation needed a channel history table.
- D1 transaction/CAS language was still too loose for publish/rollback/disable races.
- Android versionCode monotonicity was not enforced.
- Public latest API omitted schema/capability negotiation.
- R2 SHA-256 verification was underspecified for multipart upload because ETag is not SHA-256.
- KV was not strong enough as the only pre-domain rate limiter.
- Download revocation now correctly required D1 reads, but D1 failure/cost behavior was not defined.
- Emergency GitHub manifest lacked exact URL, precedence, and client use rules.
- Public API error-code contract was missing.
- Environment isolation was not specified.
- Admin authorization needed minimal roles, not just allowlist.
- Invariant tests were not mandatory.

### Codex response / plan revision

Accepted and revised `CF-UPDATE-BACKEND-PLAN.md`:

- Changed signing model from full manifest signing to immutable security payload signing. CI signs app/version/hash/asset/patch/capability metadata; release notes are mutable plain-text display metadata excluded from the security signature and tracked by audit logs.
- Added pre-rollout GitHub Release safety: ordinary pushes must not create formal latest releases; old clients must only see approved stable on GitHub latest before Cloudflare rollout.
- Moved admin mutation API to Access-protected Pages Functions same-origin facade for the no-custom-domain phase. Direct Worker admin routes are disabled until they are behind the same Access app/custom domain or require explicit bearer Access JWT.
- Split release flow by phase: Phase 1 registers approved GitHub tag assets without R2, Phase 2 adds R2 upload and validation.
- Added `channel_history` table and required append-only channel change records with revision/action/actor/request/before/after data.
- Specified CAS as conditional `UPDATE channels ... WHERE revision = ?`, affected-row verification, and audit/history in the same transaction/batch.
- Added Android `UNIQUE(app_id, platform, version_code)` and default block on publishing non-rollback versionCode regressions.
- Added `schemaVersion` and `capabilities` to public latest contract, with missing values defaulting to v1-compatible output or no-update.
- Added R2 SHA-256 object metadata/read-back verification and explicitly disallowed using multipart ETag as SHA-256.
- Replaced KV high-frequency rate limiting with Durable Object coarse rate limiting. KV remains for config/cache only.
- Defined fail-closed behavior for D1 state-check errors during downloads.
- Added public API stable errorCode contract.
- Added exact emergency manifest shape: immutable GitHub release URL, only used after Cloudflare latest failures, same public-key signature verification.
- Added `dev` / `staging` / `prod` environment isolation, separate bindings/secrets, admin environment banners, and CI restrictions.
- Added minimal roles: viewer, publisher, owner.
- Added mandatory invariant tests for CAS conflicts, disabled-release invisibility, fallback gate checks, R2 archived rollback rejection, v1/v2 compatibility, token failures, stop switches, D1 fail-closed, and releaseNotes/signature separation.

## Round 3 — Codex (manual)

VERDICT: REVISE.

Key findings:

- Architecture still used unversioned KV key `manifest:{appId}:{platform}:{channel}`, contradicting later revision-keyed cache design.
- Public API Security still said Worker-side KV rate limiting, while Cost Strategy said Durable Object and forbade KV high-frequency counters.
- Emergency manifest URL was incoherent because it was described as both fixed and tag-specific.

### Codex response / plan revision

Accepted and revised `CF-UPDATE-BACKEND-PLAN.md`:

- Architecture now states KV caches only revision-keyed render output: `manifest:{appId}:{platform}:{channel}:{revision}`. Unversioned channel state is always read from D1.
- Public API Security now uses Durable Object for coarse rate limiting. KV is no longer listed as a rate-limit counter.
- Emergency manifest now uses a client-hardcoded stable URL whose content may update. Safety relies on public-key payload signature verification and versionCode monotonic update checks, not on tag-specific immutability.

## Round 4 — Codex (manual)

VERDICT: APPROVED.

Reviewer conclusion:

- No remaining material blockers found.
- Round 3 contradictions are resolved.
- Manifest KV keys are revision-scoped with D1 as channel truth.
- Rate limiting consistently uses Durable Object rather than KV counters.
- Emergency manifest is now a client-hardcoded stable URL protected by payload signature and versionCode monotonic checks.
- Earlier Round 1/2 blockers did not reappear in material form.

## Resolution

Plan approved after 4 adversarial review rounds.

Convergence:

- Round 1: major architecture, security, fallback, schema, CI, client compatibility, and observability risks.
- Round 2: signature/editability, Access placement, old-client GitHub latest safety, phase consistency, channel history, CAS, environment, and test gaps.
- Round 3: remaining document contradictions around KV cache keys, rate limiting, and emergency manifest URL semantics.
- Round 4: approved.

## Implementation Log

### Phase 0 — 2026-06-28

Status: code-complete, pending GitHub Actions verification.

Implemented:

- Pre-rollout GitHub Release safety in `.github/workflows/build.yml`: formal GitHub Release creation is now limited to `v*` tag pushes or explicit `workflow_dispatch publish_release=true`.
- Manual publish hardening: explicit manual publishing requires `release_tag` unless the workflow is run on a tag, so branch dispatches cannot silently create `build-*` releases that become GitHub latest.
- Fixed Android signing gate: the Android build job emits `fixed_signing_configured`, and the formal release job fails closed when fixed signing secrets are absent.
- Android update service v1/v2 compatibility: Cloudflare latest query parameters include `appId`, `platform`, `channel`, `versionCode`, `schemaVersion`, and `capabilities`; v1 GitHub manifests remain parseable.
- Cloudflare fallback safety: when a Cloudflare manifest URL is compiled in, the client does not use GitHub `/latest/download` as fallback. GitHub asset fallback is limited to manifest-provided URLs or immutable tag-specific URLs derived from v1 `releaseTag`.
- Full APK fallback: the client can fall back from missing/failed incremental updates to a full APK download, verifies `apkSha256`, uses unique temp files, deletes failed partial downloads, and only installs after verification.
- Update UX: progress and failure handling now expose download bytes, percent, verification, synthesis, install, retry, full fallback, and later actions.
- Patch parser limits: maximum patch size, manifest length, operation count, operation length, copy bounds, output size, and exact output-size matching are enforced before final hash verification.
- Emergency manifest support: fixed URL configuration, payload signature requirement for emergency manifests, Ed25519 verification when the public key is compiled in, and versionCode monotonic behavior through normal update comparison.

Residual risks and follow-up:

- `flutter` and `dart` were unavailable locally, so formatting/analyze/pub-get validation must be performed by GitHub Actions or a local Flutter SDK environment.
- `pubspec.lock` was updated manually from official `pub.dev` metadata for `cryptography` because local `flutter pub get` could not run.
- The signature canonical payload contract must be mirrored exactly by CI/Worker before publishing signed v2 or emergency manifests.
- Existing old clients are still governed by GitHub latest; operators must keep GitHub latest stable-only until old clients age out.
- No Cloudflare account, token, resource creation, or production deployment was performed.

Validation recorded:

- `git diff --check` passed with only line-ending warnings.
- Text searches confirmed the app update service no longer constructs patch/full fallback URLs from GitHub `/latest/download`; it derives immutable tag asset URLs from `releaseTag`.
- Text searches confirmed the release job condition no longer includes ordinary branch `push`.

### Phase 0 follow-up — update check UX

Status: implemented after device feedback that manual "检查更新" could appear stuck at "获取更新清单" or finish without visible output.

Changes:

- Manual update checks now apply a 30-second hard timeout around manifest retrieval and cancel the underlying Dio request on timeout.
- The checking dialog now shows the active manifest source and includes a cancel button.
- Manual "already latest" and failure outcomes now use explicit dialogs instead of relying only on snackbars, so the user always gets visible output after the loading dialog closes.

Validation required:

- Install the next GitHub Actions Android artifact and tap "检查更新" on a network that can access GitHub; expected result for the current latest version is an "已是最新版本" dialog.
- Repeat with GitHub blocked or offline; expected result is a visible timeout/network failure dialog within 30 seconds, with a retry action.

### Phase 1 scaffold and GitHub Actions verification — 2026-06-28

Status: code-complete and verified by GitHub Actions on Linux.

Implemented:

- Added `cloudflare/update-service/` scaffold with Worker, migration, scripts, admin placeholder, docs, TypeScript config, Wrangler config, package-lock, and generated Env binding types.
- Implemented public latest, primary download, and GitHub gated fallback routes. Download and fallback both validate HMAC token and D1 state before redirecting to immutable GitHub tag asset URLs.
- Implemented CI candidate registration with deploy token hash verification, fixed Android signing gate, formal release intent gate, immutable GitHub URL validation, idempotency, and candidate-only D1 writes.
- Added Durable Object rate limiter. KV is only used for revision-keyed manifest cache and is not used as a high-frequency counter.
- Added D1 schema constraints, indexes, `channel_history`, CAS revision update support via channel update predicates/triggers, append-only audit/history triggers, and disabled-release channel guards.
- Added invariant tests for the required Phase 1 safety cases.
- Added a GitHub Actions workflow to run the Cloudflare Worker typecheck and invariant tests on Linux without deploying Cloudflare resources.
- Fixed the first GitHub Actions invariant failures by replacing `meta.changes` CAS detection with `UPDATE ... RETURNING`, disabling automatic redirect following in the fake GitHub fallback test, and exercising D1 fail-closed behavior through the Worker/Hono error handler.
- Added staging bootstrap tooling and an operator guide: `bootstrap-staging.ps1`, `bootstrap-staging.mjs`, and `docs/STAGING-SETUP.md`. The script is staging-only, requires explicit confirmation, and automates D1/KV/R2 creation, Wrangler config update, migration apply, Worker deploy, secret writes, and smoke checks.

Residual risks and follow-up:

- No Cloudflare resources or Access application were created. Direct Worker admin mutation routes remain disabled until an Access-protected Pages Functions facade or equivalent safe entry point is implemented.
- The staging bootstrap has not been run against a real Cloudflare account in this session because no account ID or API token was provided.
- Local Worker runtime tests remain blocked by a Miniflare/workerd access violation on Windows before any test files execute. Linux GitHub Actions is the current runtime verification source.
- R2 primary download, R2 upload verification, retention, restore, and Pages admin UI are not implemented in this phase.

Validation recorded:

- `npm run cf-typegen` succeeded with `wrangler types --include-runtime false worker-configuration.d.ts`.
- `npm run check` passed with `tsc --noEmit`.
- `npm test` was attempted and failed before executing tests due to local workerd `0xc0000005` access violation.
- `npm run check` was re-run after the CAS/test-harness fixes and passed.
- GitHub Actions `Cloudflare Update Service Checks` passed on Linux for commit `ab44e6e`: `https://github.com/Eitan-S-23/Trace/actions/runs/28325141952`.
- GitHub Actions `Build APK and EXE Release` passed for commit `ab44e6e`: `https://github.com/Eitan-S-23/Trace/actions/runs/28325141953`. Android APK, Windows package, and Pages jobs passed; the formal GitHub Release job was skipped on branch push.
- Staging bootstrap validation was limited to syntax/static checks and dry-run/help execution. No real Cloudflare API mutation or deploy was run.

### Phase 1 follow-up — staging deployment and CI candidate registration wiring — 2026-06-29

Status: implemented locally, pending GitHub Actions formal release verification.

Implemented:

- Added `.gitignore` coverage for `cloudflare/update-service/.bootstrap/` so bootstrap summaries containing raw deploy tokens stay local.
- Recorded staging D1/KV/R2 binding IDs in `worker/wrangler.jsonc`; production remains unconfigured.
- Added `build-github-release-metadata.mjs` to validate release assets and generate the `/api/ci/releases` payload from `ble-monitor-update.json`, APK, and patch files.
- Updated the Android GitHub Actions build to compile `TRACE_CLOUDFLARE_UPDATE_MANIFEST_URL` from the `TRACE_UPDATE_SERVICE_URL` repository secret when present.
- Updated the formal release job to generate candidate metadata after GitHub Release upload and call `register-release.mjs` with `TRACE_UPDATE_SERVICE_URL` and `TRACE_DEPLOY_TOKEN`.
- Preserved the Phase 0 safety gate: only `v*` tags or `workflow_dispatch publish_release=true` can reach release creation and Cloudflare candidate registration.
- Updated staging docs to describe current CI registration verification and the remaining publish boundary.

Residual risks and follow-up:

- CI uses a staging-only placeholder `payloadSignature` until a real Ed25519 signing secret and matching client public key are configured. Do not publish those candidates to clients.
- The Access-protected admin facade is still required before candidates can be safely published to `stable` or `beta`.
- R2 primary distribution is still deferred to Phase 2; registered assets remain immutable GitHub tag URLs in Phase 1.
- A formal GitHub Actions run must still verify candidate registration against the deployed staging Worker.

Validation recorded:

- `node --check` passed for `build-github-release-metadata.mjs`, `register-release.mjs`, and `bootstrap-staging.mjs`.
- Synthetic metadata generation with temporary dummy release assets succeeded.
- `npm run check` passed in `cloudflare/update-service/worker`.
- `git diff --check` passed with only line-ending warnings.
- `npm test` is still blocked locally by the known Windows workerd `0xc0000005` crash before test execution.
- Local Flutter/Gradle build/package commands were not run.

### Phase 1 follow-up — Access admin facade and payload signing wiring — 2026-06-29

Status: implemented locally, pending Cloudflare Access configuration, Pages deployment, and real release verification.

Implemented:

- Added a Phase 1 Pages Functions admin facade under `cloudflare/update-service/admin`.
- Kept direct Worker admin routes disabled; admin mutations now exist only behind the intended Pages Functions same-origin surface.
- Implemented Cloudflare Access JWT verification with issuer/audience/expiry/`nbf` checks, RS256 JWKS verification, email allowlist, and role derivation.
- Implemented CSRF token issuance through `/api/admin/session` and required same-origin `Origin` plus `X-CSRF-Token` for mutations.
- Added JSON admin API endpoints for session, channels, releases, publish/rollback, release notes, and disable-unpublished-release operations.
- Added a staging Pages `wrangler.jsonc` with D1 binding. Access values are intentionally not committed and must be supplied as Pages secrets.
- Added Ed25519 payload signing key generation, and wired GitHub Actions to use public/private signing secrets when present.
- Added admin facade typecheck to the Cloudflare Update Service Checks workflow.

Residual risks and follow-up:

- A Cloudflare Access application must be created and its issuer, AUD tag, and role email variables must be configured before deploying the admin Pages project.
- The admin facade has not been exercised against a real Cloudflare Access JWT.
- Real payload signing secrets must be generated and added to GitHub before any candidate is published to phones.
- The final React admin UI remains Phase 3; current admin operations are JSON API calls.
- R2 primary distribution remains Phase 2.

Validation recorded:

- `npm install` generated `cloudflare/update-service/admin/package-lock.json`.
- `npm run check` passed for `cloudflare/update-service/admin`.
- `npm run check` passed for `cloudflare/update-service/worker`.
- `node --check` passed for the payload signing key generator and candidate metadata generator.
- The payload signing key generator self-check passed with output redirected to a temporary file and removed.
- `git diff --check` passed with only line-ending warnings.
- `npm test` was attempted in `cloudflare/update-service/worker` and remains blocked before test execution by the known Windows workerd `0xc0000005` runtime crash.
- Local Flutter/Gradle build/package commands were not run.

### Phase 1 follow-up — admin Pages deployment script verification — 2026-06-29

Status: staging Pages project created and deploy command path verified; Access secrets still pending.

Implemented:

- Added `deploy-admin-staging.ps1` and `deploy-admin-staging.mjs` to automate staging admin Pages setup.
- The script creates or reuses `trace-update-admin-staging`, writes Access configuration from shell environment variables as Pages secrets, runs admin TypeScript checking, and deploys `admin/public` plus Pages Functions.
- The script now exposes Wrangler output when Pages project listing fails and explicitly shows whether `CLOUDFLARE_API_TOKEN` is set, because that variable can make Wrangler use an insufficient custom token instead of the browser login.
- Removed Access/admin allowlist names from the committed Pages `vars` so Pages secrets can use those names without duplicate binding conflicts.
- Updated the admin README and staging setup guide to include the required `wrangler pages project create` command before `wrangler pages deploy`.
- Updated the docs to explain the `CLOUDFLARE_API_TOKEN` conflict and the PowerShell command to unset it for the Pages deploy path.
- Created the Cloudflare Pages project `trace-update-admin-staging` and deployed the admin facade to staging.

Residual risks and follow-up:

- Access environment variables were not present in the shell during verification, so Pages Access secrets were intentionally skipped.
- Local `pages.dev` HTTPS smoke checks still fail on this Windows/proxy setup even though Wrangler API deploy/list commands succeed.
- Protect the Pages domain with the Cloudflare Access application and then write the Access issuer, AUD, and role email variables before using admin mutation endpoints.

Validation recorded:

- `npx wrangler pages project create trace-update-admin-staging --production-branch main --compatibility-date 2026-06-28 --compatibility-flag nodejs_compat` succeeded.
- `npx wrangler pages deploy .\public --project-name trace-update-admin-staging --branch main --commit-dirty=true` succeeded.
- `npx wrangler pages project list` confirmed `trace-update-admin-staging.pages.dev`.
- `npx wrangler pages secret list --project-name trace-update-admin-staging` succeeded.
- `node --check cloudflare/update-service/scripts/deploy-admin-staging.mjs` passed.
- `deploy-admin-staging.ps1 -DryRun` passed.
- `deploy-admin-staging.ps1 -Yes -SkipSecrets -SkipDeploy` passed.
- `deploy-admin-staging.ps1 -Yes -SkipSecrets` passed and deployed `https://3718ac26.trace-update-admin-staging.pages.dev`.
- A negative-path run with a deliberately invalid `CLOUDFLARE_API_TOKEN` now prints the underlying Wrangler auth failure and the script hint.
- After Pages secrets were uploaded, the first deploy failed with duplicate binding name `ACCESS_JWT_AUD`; removing committed Access `vars` fixed the conflict.
- `deploy-admin-staging.ps1 -Yes -SkipSecrets` passed after the duplicate binding fix and deployed `https://fa6e2e77.trace-update-admin-staging.pages.dev`.
- Local Flutter/Gradle build/package commands were not run.

### Phase 1 follow-up — lightweight admin UI — 2026-06-29

Status: implemented and deployed to staging.

Implemented:

- Replaced the static admin placeholder with a lightweight operator UI.
- The UI fetches the Access session, channel list, and release list from the protected Pages Functions API.
- The UI can edit release notes, publish to beta, publish to stable with confirmation, and disable unpublished releases.
- The UI keeps direct Worker admin routes disabled and uses the same-origin Access-protected Pages facade.

Residual risks and follow-up:

- The UI is intentionally minimal for Phase 1. The full React admin console remains Phase 3.
- End-to-end publish button validation requires an authenticated browser session.

Validation recorded:

- Inline script syntax check passed with Node.
- `git diff --check` passed for the changed admin page with only line-ending warnings.
- `npx wrangler pages deploy .\public --project-name trace-update-admin-staging --branch main --commit-dirty=true` succeeded and deployed `https://7dd9a490.trace-update-admin-staging.pages.dev`.
- Local Flutter/Gradle build/package commands were not run.

### Phase 1 follow-up — beta publication verification — 2026-06-29

Status: Access-protected admin UI successfully published the staging Android candidate to `beta`.

Implemented:

- Published `rel_trace_android_v1_0_4` / `v1.0.4` to the Android `beta` channel through the Pages admin UI.
- Confirmed the D1 channel pointer moved by CAS revision update: `beta` revision is now `1` and points to `rel_trace_android_v1_0_4`.
- Confirmed `stable` remains unpublished and continues to return no update.
- Confirmed the public v2 manifest includes the Ed25519 `payloadSignature`, full APK fallback, and three patch entries.
- Confirmed the publish operation wrote both `channel_history` and append-only `audit_logs` records for the Access actor.
- Confirmed fallback URLs are Worker-gated and redirect only to tag-specific GitHub Release assets, not GitHub `/latest/download`.

Residual risks and follow-up:

- Real phone beta installation/update verification is still required before publishing the same candidate to `stable`.
- R2 primary download remains Phase 2; the verified Phase 1 path still serves immutable GitHub tag assets through Worker-issued short-lived download/fallback URLs.
- Signed download tokens are intended for GET requests. HEAD-based smoke checks return `401`; use non-following GET checks when validating redirect status without downloading files.

Validation recorded:

- `npx wrangler d1 execute trace-update-staging --env staging --remote --command "SELECT c.name, c.platform, c.revision, c.current_release_id, r.release_tag, r.version_code, r.state FROM channels c LEFT JOIN releases r ON r.id = c.current_release_id ORDER BY c.platform, c.name;"` succeeded and returned `beta` -> `rel_trace_android_v1_0_4`, revision `1`, versionCode `30`; `stable` remains empty.
- `curl.exe` against the beta public latest endpoint returned `updateAvailable: true`, `releaseTag: v1.0.4`, `versionCode: 30`, and three patch entries.
- `curl.exe` against the stable public latest endpoint returned `NO_UPDATE`.
- Non-following GET checks against the first patch fallback and full APK fallback returned `302` redirects to `/releases/download/v1.0.4/...`.
- D1 queries confirmed one `channel_history` publish row for `ch_trace_android_beta` and one `audit_logs` publish row for the same channel, in addition to the CI `register_candidate` audit row.
- Local Flutter/Gradle build/package commands were not run.

### Phase 2 — R2 primary distribution wiring — 2026-06-29

Status: implemented and verified on staging through the R2 backfill path; pending a Linux GitHub Actions formal-release run for the new CI upload path.

Implemented:

- Added Phase 2 R2 upload into the formal GitHub Release job before Cloudflare candidate registration.
- Added `upload-r2-assets.mjs` to validate release assets locally, upload versioned R2 objects, read them back, verify SHA-256, and enrich candidate metadata with `r2Key` plus `r2Verified: true`.
- Hardened `upload-r2-assets.mjs` with bounded retries and per-operation timeouts so transient Wrangler/R2 upload or read-back hangs can recover.
- Hardened `register-release.mjs` with bounded retries and request timeouts for CI registration.
- Worker CI registration now validates R2 key shape, requires `r2Verified`, checks R2 object existence/size through the R2 binding, stores new assets as `r2_state = available`, and can idempotently update existing matching asset rows to available.
- Added restricted `r2Backfill` support for existing releases so Phase 1 GitHub-backed candidates can be moved to R2 without rebuilding APKs. Backfill is limited to existing releases and matching commit/asset identity.
- Added `backfill-r2-release.mjs` and `backfill-r2-release.ps1` for staging operators. The script can read the ignored bootstrap summary for the staging Worker URL/token without printing secrets, downloads only Android update assets, retries GitHub downloads, and can skip upload/register for no-write validation.
- Primary `/api/public/download` now streams R2 objects when available and sets `X-Trace-Asset-Source: r2`, immutable cache headers, content length, ETag, content type, and content disposition.
- GitHub fallback remains Worker-gated and still redirects only to immutable tag-specific Release URLs.
- Added invariant tests for R2 primary streaming, missing R2 object rejection during CI registration, and R2 backfill state update.
- Updated `docs/README.md` and `docs/STAGING-SETUP.md` with Phase 2 secrets, upload/backfill flow, D1 checks, and R2-vs-GitHub fallback verification commands.
- Deployed the updated staging Worker and Pages admin facade after R2 backfill verification.

Residual risks and follow-up:

- Run a formal GitHub Actions release on Linux to verify the `.github/workflows/build.yml` R2 upload path end-to-end after the retry/timeout changes.
- Local Node `fetch` to `workers.dev` can still time out through this Windows/proxy setup; PowerShell/curl successfully reached the same Worker endpoints.
- Local Worker runtime tests still cannot run on this Windows host because workerd/Miniflare crashes with the known `0xc0000005` access violation. Linux GitHub Actions remains the runtime test source.
- R2 retention cleanup, restore-from-GitHub, backup scheduling, manifest preview polish, and lightweight stats remain Phase 3+.

Validation recorded:

- `npx wrangler r2 object put --help` and `npx wrangler r2 object get --help` confirmed the Wrangler R2 metadata/readback flags used by `upload-r2-assets.mjs`.
- `node --check cloudflare/update-service/scripts/upload-r2-assets.mjs` passed.
- `node --check cloudflare/update-service/scripts/backfill-r2-release.mjs` passed.
- `node --check cloudflare/update-service/scripts/register-release.mjs` passed.
- `node --check cloudflare/update-service/scripts/deploy-admin-staging.mjs` passed.
- `npm run check` passed for `cloudflare/update-service/worker`.
- `npm run check` passed for `cloudflare/update-service/admin`.
- `npm test` was attempted for `cloudflare/update-service/worker`, but local workerd/Miniflare crashed before executing tests with the known Windows `0xc0000005` access violation.
- `backfill-r2-release.ps1 -ReleaseTag v1.0.5 -DryRun` passed and printed a non-writing plan.
- `gh release view v1.0.5 -R Eitan-S-23/Trace --json assets` confirmed Android APK, update manifest, five `.tpatch` files, and Windows assets exist in the GitHub Release.
- A no-write metadata-generation run against `v1.0.5` succeeded before the download-scope optimization, validating the GitHub Release manifest/APK/patch hash chain without R2 upload or D1 registration.
- `backfill-r2-release.ps1 -ReleaseTag v1.0.5 -Yes -SkipDownload -KeepAssets -AssetsDir $env:TEMP\trace-r2-backfill-debug` uploaded all seven Android update assets to R2 and read them back with SHA-256 verification.
- One 47 MB patch upload exposed a too-short 180-second timeout and was recovered by rerunning with `TRACE_R2_OPERATION_TIMEOUT_MS=600000`; the script now supports this operator override.
- Node registration to `workers.dev` timed out through the local proxy, but PowerShell `Invoke-RestMethod` successfully posted the verified metadata to `/api/ci/releases`. The Worker returned `{ ok: true, releaseId: rel_trace_android_v1_0_5, r2Backfill: true, r2AssetsUpdated: 7 }`.
- `npx wrangler d1 execute ... release_assets ...` confirmed APK, manifest, and five patch rows for `rel_trace_android_v1_0_5` have `r2_state = available` and versioned `r2_key` values.
- `npx wrangler deploy --env staging` deployed the updated Worker to `https://trace-update-service-staging.tangjichentudou.workers.dev`.
- `deploy-admin-staging.ps1 -Yes -SkipSecrets` deployed the updated Pages admin facade to staging.
- Public latest for Android `stable` and `beta` both returned `v1.0.5` / versionCode `31` after publication.
- A signed primary patch download returned `200`, `X-Trace-Asset-Source: r2`, `Content-Length: 513666`, and immutable cache headers.
- The matching fallback URL returned `302` to `/releases/download/v1.0.5/...` and did not use `/latest/download`.
- Local Flutter/Gradle build/package commands were not run.

### Phase 2 follow-up — one-command staging publish automation — 2026-06-29

Status: implemented locally; dry-run verified.

Implemented:

- Added `cloudflare/update-service/scripts/publish-staging-release.ps1` and `publish-staging-release.mjs` as a staging-only operator wrapper.
- The wrapper chains existing GitHub Release asset validation, R2 upload/read-back verification, `/api/ci/releases` R2 backfill registration, D1 channel CAS publish, public latest manifest verification, primary signed patch download verification, and gated GitHub fallback redirect verification.
- The wrapper refuses non-staging D1 targets by default and does not run local Flutter, Gradle, Dart, Windows, or packaging builds.
- The wrapper requires all active Android assets to be R2 `available` before publishing unless the operator explicitly passes `-AllowPartialR2` for temporary staging diagnostics.
- The registration step uses Node fetch first and falls back to PowerShell `Invoke-RestMethod` on Windows without printing the deploy token, matching the local proxy behavior observed during manual R2 backfill.
- Updated staging docs and the update-service README with the one-command release flow and safety notes.

Residual risks and follow-up:

- Production release automation still requires GitHub Actions secrets `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN`; this wrapper is not a substitute for CI R2 upload in formal releases.
- The wrapper uses direct Wrangler D1 CAS updates for staging operator convenience. Production admin mutation should continue to use the Access-protected Pages facade or an equivalent protected same-origin path.
- The full end-to-end non-dry-run path still depends on Cloudflare/GitHub network stability for large APK and patch downloads/uploads.

Validation recorded:

- `node --check cloudflare/update-service/scripts/publish-staging-release.mjs` passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\cloudflare\update-service\scripts\publish-staging-release.ps1 -ReleaseTag v1.0.6 -Channels stable,beta -DryRun` passed and performed no writes.
- Local Flutter/Gradle build/package commands were not run.

### Phase 2 follow-up — GitHub Actions secret configuration wrapper — 2026-06-29

Status: implemented locally; pending operator-filled local config.

Implemented:

- Added `cloudflare/update-service/scripts/configure-github-actions-secrets.ps1`, which reads a local JSON config and writes repository-level GitHub Actions secrets and variables with `gh secret set` / `gh variable set`.
- Added `cloudflare/update-service/github-actions-secrets.staging.example.json` as the fill-in template for staging configuration.
- Added `.gitignore` coverage for `cloudflare/update-service/.github-actions-secrets*.local.json`, so real Cloudflare API tokens, deploy tokens, signing secrets, and payload signing keys are not committed.
- The wrapper can read `TRACE_UPDATE_SERVICE_URL`, `TRACE_DEPLOY_TOKEN`, and `TRACE_R2_BUCKET` from `.bootstrap/staging-summary.json` when configured.
- Blank local config values preserve already configured GitHub secret/variable names; if a required name is neither filled locally nor present in GitHub, the wrapper fails before writing.
- Secret values are passed to `gh secret set` through stdin and are not printed.

Residual risks and follow-up:

- GitHub does not allow reading secret values back, so the wrapper verifies presence by name only. Incorrect secret values still require a GitHub Actions run to detect.
- The operator must fill `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN`; these are not available from the bootstrap summary.
- Payload signing keys should be generated once and kept stable for client compatibility.

Validation recorded:

- PowerShell parser validation passed for `cloudflare/update-service/scripts/configure-github-actions-secrets.ps1`.
- `configure-github-actions-secrets.ps1 -Config cloudflare/update-service/github-actions-secrets.staging.example.json -DryRun` correctly performed no writes and failed closed on the unfilled example config, reporting missing `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN`.
- Local Flutter/Gradle build/package commands were not run.

### Phase 2 follow-up — v1.0.6 staging update verification — 2026-06-29

Status: staging channel published and verified for the current installed `1.0.5 (31)` phone path.

Implemented:

- The GitHub Actions formal release run for `v1.0.6` succeeded and produced signed Cloudflare release metadata for versionCode `32`.
- The `v1.0.6` candidate was registered in staging D1 as `rel_trace_android_v1_0_6`.
- Android `stable` and `beta` channels now point to `rel_trace_android_v1_0_6`.
- The `31 -> 32` incremental patch and one small `30 -> 32` patch were uploaded to R2, read-back verified, and registered as `r2_state = available`.
- The `v1.0.6` manifest asset was also uploaded to R2 and registered as available.
- A corrupted/mismatched R2 APK object created during a failed Wrangler large-object upload was deleted, and the APK asset row was restored to `r2_state = not_uploaded` with an audit log entry. This prevents clients from receiving a bad full APK from the R2 primary endpoint.

Residual risks and follow-up:

- Large APK upload from this Windows host through Wrangler remains unstable. Until CI has `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` configured and the Linux GitHub Actions R2 upload path is verified, the `v1.0.6` full APK primary URL intentionally fails closed and full APK fallback goes through the Worker-gated immutable GitHub Release URL.
- Only the current `1.0.5 (31) -> 1.0.6 (32)` phone path is fully R2-primary verified. Older installed APK hashes may receive large patches that are still GitHub fallback-only.
- `publish-staging-release.ps1 -AllowPartialR2` remains a staging diagnostic escape hatch only and must not be used for normal releases.

Validation recorded:

- D1 confirmed `stable` and `beta` point to `rel_trace_android_v1_0_6` / `v1.0.6` / versionCode `32`.
- D1 confirmed `ble-monitor-android-from-31-11ae0ed6a0fa-to-32.tpatch` has `r2_state = available`.
- Public latest for Android `stable` from versionCode `31` returned `v1.0.6`, schema v2 payload signature metadata, and the `31 -> 32` patch.
- The signed `31 -> 32` primary patch URL returned `200`, `X-Trace-Asset-Source: r2`, the expected content length, and a SHA-256 match.
- The full APK primary URL returned `BACKEND_UNAVAILABLE` after the unsafe R2 APK state was cleared.
- The full APK fallback URL returned `302` to a tag-specific GitHub Release URL under `/releases/download/v1.0.6/...` and did not use `/latest/download`.
- Local Flutter/Gradle build/package commands were not run.

### Phase 2 follow-up — v1.0.7 Linux CI R2 upload verification — 2026-06-29

Status: GitHub Actions Linux R2 upload path verified; staging `stable` and `beta` now point to `v1.0.7`.

Implemented:

- Configured the previously missing GitHub Actions Cloudflare secrets and variables with `configure-github-actions-secrets.ps1 -Yes`.
- Fixed `upload-r2-assets.mjs` to resolve metadata, asset, output, and Wrangler cwd paths to absolute paths before invoking Wrangler from `cloudflare/update-service/worker`.
- Fixed `configure-github-actions-secrets.ps1` to write stdin secrets with UTF-8 no BOM and normalize leading BOM characters from config values before upload.
- Rewrote the affected GitHub Actions secrets after the BOM fix. The previous `CLOUDFLARE_API_TOKEN` secret failed Wrangler because it contained `U+FEFF`.
- Re-ran the formal `build.yml` workflow for `v1.0.7`; the successful run uploaded APK, manifest, and seven patch assets to R2, read them back, verified SHA-256, and registered the Cloudflare candidate.
- Published `v1.0.7` to Android `stable` and `beta` with the staging publish wrapper using `-SkipBackfill`, because CI had already uploaded and verified every active Android asset.

Residual risks and follow-up:

- The first failed `v1.0.7` workflow created the GitHub tag at `6771b5e`; the successful D1 registration came from workflow run `28377025733` at `cce70a3`. The app artifact version remains `1.0.7+33`; only CI/operator scripts changed between those commits.
- Local GitHub CLI/API calls still intermittently hit keyring/TLS/EOF timeouts on this Windows host; the scripts now retry transient `gh` failures, but operator commands may still need manual retry.
- R2 retention cleanup, restore-from-GitHub, backup scheduling, manifest preview polish, and lightweight stats remain Phase 3+.

Validation recorded:

- `configure-github-actions-secrets.ps1 -DryRun` passed after the BOM/encoding fix.
- `configure-github-actions-secrets.ps1 -Yes` completed and verified required GitHub secret and variable names by name.
- `node --check cloudflare/update-service/scripts/upload-r2-assets.mjs` passed.
- `git diff --check` passed for both script fixes with only line-ending warnings.
- GitHub Actions run `28377025733` completed successfully. In the `Create GitHub Release` job, `Upload Cloudflare R2 assets` and `Register Cloudflare candidate` both succeeded.
- D1 confirmed `rel_trace_android_v1_0_7` / `v1.0.7` / versionCode `33` exists as `candidate` with commit `cce70a38491487139b353f4722b921e39edcbdb4` and run id `28377025733`.
- D1 confirmed APK, manifest, and seven patch assets for `rel_trace_android_v1_0_7` all have `r2_state = available` and present `r2_key` values.
- `publish-staging-release.ps1 -ReleaseTag v1.0.7 -Channels stable,beta -SkipBackfill -DryRun` printed the no-write plan.
- `publish-staging-release.ps1 -ReleaseTag v1.0.7 -Channels stable,beta -SkipBackfill -Yes` published `stable` revision `3` and `beta` revision `4`.
- The staging publish wrapper verified latest manifests for both channels and verified the `31 -> 33` primary patch download source is R2.
- D1 audit logs recorded `register_candidate` for `rel_trace_android_v1_0_7` and system `publish` actions for both Android channels.
- Local Flutter/Gradle build/package commands were not run.
