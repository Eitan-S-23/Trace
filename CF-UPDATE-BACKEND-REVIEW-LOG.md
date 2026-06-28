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
