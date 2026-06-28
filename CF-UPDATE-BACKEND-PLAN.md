# Plan: Cloudflare 更新后台与分发系统

_Locked via grill — by Codex + user_

## Goal

将 Trace 当前依赖 GitHub Release 的应用更新机制迁移为 Cloudflare 主控的更新后台：GitHub Actions 继续负责构建 Android APK、Windows 包和增量 tpatch；Cloudflare Workers + D1 + R2 + KV + Pages 负责发布控制台、版本事实源、主下载分发、manifest 缓存、回滚、停更和防滥用。目标是正常个人使用尽量零成本，GitHub Release 保留为完整历史备份和 fallback。

## Architecture

- GitHub Actions 继续构建 Android APK、Windows zip/exe、tpatch、manifest。
- Cloudflare D1 作为版本、资产、补丁、渠道和审计日志的事实源。
- Cloudflare R2 作为主文件源，存放 APK、Windows 包、tpatch、manifest。
- Cloudflare KV 只缓存按 revision 命名的 latest manifest 渲染结果，key 为 `manifest:{appId}:{platform}:{channel}:{revision}`，首版 TTL 为 60 秒；未带 revision 的 channel 状态始终从 D1 读取。
- Cloudflare Workers 提供 public/admin/ci API。
- Cloudflare Pages 部署发布控制台前端。
- GitHub Release 继续创建，作为完整历史备份、管理员恢复源和受 Worker gate 保护的 fallback。
- 首版使用 `*.workers.dev` 和 `*.pages.dev`，以后有自定义域名时集中替换配置。

## Pre-Rollout GitHub Release Safety

在任何 Cloudflare 客户端发布前，必须先修正当前 GitHub Release 行为：

- 普通 push 不再创建会成为 GitHub latest 的正式 release。
- CI 普通构建只上传 workflow artifacts，或创建 draft/prerelease。
- 只有 tag 发布或显式 `workflow_dispatch publish_release=true` 才创建正式 GitHub Release。
- 旧客户端仍会读取 GitHub `/latest/download/ble-monitor-update.json`，因此 GitHub latest 必须只指向人工认可的 stable 构建。
- Cloudflare fallback 永远使用 immutable tag-specific asset URL，不使用 `/latest/download`。

## Implementation Phases

Phase 0: 发布前置安全门槛。

- 固定 Android release signing 必须成为 CI 硬性前置条件；缺少固定签名密钥时不得登记 Cloudflare candidate。
- 客户端先支持 Manifest v1/v2 双解析、Cloudflare primary、GitHub fallback、全量 APK fallback、patch 安全限制。
- 新增 `minClientVersionCode` 或 client capability 参数，旧客户端只收到兼容 manifest。

Phase 1: Worker + D1 控制面，先使用 GitHub tag-specific assets。

- Cloudflare Worker 先接管 latest/channel 决策。
- 下载 URL 先由 Worker redirect 到已批准 release 的 immutable GitHub tag asset，不使用 `/latest/download`。
- 这一阶段验证 D1 channel、发布/回滚/禁用、Access、审计和客户端兼容。
- Phase 1 不要求 R2 上传成功，也不把 R2 作为主下载源。

Phase 2: R2 成为主下载源。

- CI 上传 R2 后登记 D1。
- Worker 下载接口代理 R2 stream。
- GitHub tag-specific URL 保留为 gated fallback 或管理员恢复源。

Phase 3: Pages 发布控制台完善。

- 增加 manifest 预览、R2 清理、轻量统计、备份任务和操作确认。

## Scope

- 首版重点支持 Android 应用内更新。
- Android 更新优先使用增量 tpatch。
- 增量不可用、下载失败、校验失败或合成失败时，提供全量 APK fallback。
- Windows 首版只做资产上传、后台查看和网页下载链接管理。
- Windows 不做应用内自动更新、安装器或进程自替换。
- 后台首版包含 Dashboard、Releases、Release Detail、Audit Logs。
- 后台登录使用 Cloudflare Access，不做自建登录页。

## Release Flow

1. GitHub Actions 构建成功。
2. CI 继续创建 GitHub Release。
3. 只有 tag 发布或显式 `workflow_dispatch publish_release=true` 才登记 Cloudflare candidate；普通 push build 不进入 D1/R2 发布控制面。
4. Phase 1：CI 登记 approved GitHub tag asset metadata，不要求 R2 asset。
5. Phase 2：CI 使用标准化 R2 S3 API 或 Wrangler 直传产物到 R2，并用 metadata/read-back sha256 验证对象存在、大小和哈希。
6. CI 调用 Worker `/api/ci/releases` 登记元数据到 D1，登记必须按 `releaseTag`、`runId`、`commitSha` 幂等。
7. 新版本状态为 `candidate`，不会自动发布给客户端。
8. 管理员在 Pages 发布控制台人工发布到 `stable` 或 `beta`。
9. Worker 根据 D1 channel 指针和 channel revision 生成 latest manifest。
10. 发布、回滚、禁用后递增 channel revision；KV 只缓存按 revision 命名的渲染结果，不作为 channel 事实源。
11. 客户端默认请求 Cloudflare manifest；Cloudflare 不可用时只使用静态签名 emergency manifest 或已批准 immutable GitHub tag fallback，不使用 GitHub `/latest/download`。

## Channels

- 首版只支持 `stable` 和 `beta`。
- 客户端默认请求 `stable`。
- 测试设备可切换到 `beta`。
- 暂不做百分比灰度、地区灰度、设备白名单。
- Channel 指针按 `app_id + platform + channel` 建模，Android 与 Windows 的发布完整性分开判断。
- Android channel 发布必须满足 APK、manifest、必要 patch metadata 完整。
- Windows 资产不影响 Android release 是否可发布；Windows 首版只影响网页下载和后台资产状态。

## Authentication And Admin API Placement

- Pages 后台由 Cloudflare Access 保护。
- 无自定义域名阶段，admin mutations 不直接暴露在独立 `*.workers.dev` API 上。
- Admin API 首版放在 Access 保护的 Pages Functions 同源路径，或由 Pages Functions 作为 admin facade 调用 Worker service binding。
- 如果后续直接启用 Worker admin routes，必须放在同一个 Access 应用保护的 custom domain 下，或要求浏览器显式提交可验证的 bearer Access JWT。
- Admin API 每次请求都校验 Access JWT 的 issuer、audience、expiry、email allowlist 和角色。
- Admin API mutation 使用严格 Origin 校验、非通配 CORS，并要求 CSRF token 或显式 bearer Access JWT。
- CI API 使用独立 `DEPLOY_TOKEN`。
- `DEPLOY_TOKEN` 首版仅用于幂等 CI registration，Worker 只存哈希值；后续优先改为 GitHub OIDC claim 校验。
- Public latest API 不做用户登录鉴权。
- 操作日志记录 Access 用户邮箱或 CI actor。

最小角色：

- `viewer`：只读 Dashboard、Release、Manifest 预览、Audit Logs。
- `publisher`：发布/回滚 beta，编辑 release notes。
- `owner`：发布/回滚 stable，禁用 release/asset，清理 R2，修改停更开关。

## Public API Security

- `/api/public/latest` 公开只读。
- `/api/public/latest` 只接受白名单参数：`appId`、`platform`、`channel`、`versionCode`、`schemaVersion`、`capabilities`。
- 下载接口使用短期签名 URL。
- 签名 token 包含 method、assetId、releaseId、expiresAt、keyVersion、HMAC signature。
- Worker 下载前校验 token、asset 存在、asset 未禁用、release 未 disabled、channel 未停更。
- Worker 不允许客户端传任意 R2 key。
- 当前没有自定义域名，不能假设 `*.workers.dev` 可使用完整 zone-level WAF / Rate Limiting；首版使用 Durable Object 实现粗粒度限速，后续绑定自定义域名后再加 Cloudflare WAF / Rate Limiting。
- Worker 内只做参数校验、状态校验、token 校验和必要日志。
- 后台提供紧急停更开关。
- GitHub fallback 不能作为 direct URL 暴露给客户端；fallback 必须走 Worker endpoint，由 Worker 校验 D1 状态后 redirect 到 immutable tag-specific GitHub asset。

## D1 Schema

首版表：

- `apps`
- `app_config`
- `releases`
- `release_assets`
- `patches`
- `channels`
- `channel_history`
- `audit_logs`

`app_id` 首版固定为 `trace`，但 schema 预留多应用能力。

Migration 必须包含：

- 外键约束和 `ON DELETE` 策略。
- `CHECK` 约束限制枚举字段。
- `UNIQUE` 约束保证 app/channel/platform/releaseTag/runId/asset key 不重复。
- Android release 增加 `UNIQUE(app_id, platform, version_code)`。
- patch lookup 索引：`app_id, platform, to_release_id, from_version_code, old_sha256`。
- channel lookup 索引：`app_id, platform, name`。
- asset lookup 索引：`release_id, platform, asset_type`。
- channel history 索引：`channel_id, revision` 和 `release_id, created_at`。
- audit log 按 `created_at` 和 actor 查询的索引。
- 迁移启用 foreign key enforcement。

## Release State And Channel Revision

- `releases.state` 只保存人工/终态状态：`candidate` 或 `disabled`。
- UI 中的 `published` 由 `channels.current_release_id` 是否指向该 release 派生。
- UI 中的 `superseded` 由该 release 曾被发布但当前无 channel 指向派生。
- `channels` 保存 `current_release_id`、`revision`、`disable_latest`、`disable_downloads`、`maintenance_message`。
- `channel_history` 追加记录每次 channel 变更：`channel_id`、`release_id`、`revision`、`action`、`actor`、`created_at`、`request_id`、`before_json`、`after_json`。
- 所有发布、回滚、禁用操作必须在一个显式事务或 D1 batch 中完成。
- Channel 更新使用单条条件更新：`UPDATE channels SET current_release_id = ?, revision = revision + 1 WHERE id = ? AND revision = ? AND disable_latest = 0`。
- 更新后必须检查 affected rows；不是 1 则返回 CAS conflict，不得继续写 audit/history。
- audit log 与 channel_history 必须在同一事务/batch 中追加。
- 禁止 channel 指向 disabled release；该规则由事务逻辑和可选触发器双重保护。
- 禁用 release 前必须检查所有 channel；若仍被引用，必须先切换 channel 或执行“禁用并自动回滚到上一可用版本”。
- Android stable/beta 发布默认禁止 `versionCode <= 当前 channel versionCode`；只有明确标记为 rollback 的操作可以指向较低 versionCode。

允许人工转换：

- `candidate -> disabled`
- `candidate -> channel current`，表现为 published。
- `channel current -> previous release`，原 release 表现为 superseded。
- `superseded derived -> disabled`

## Manifest v2

使用 `schemaVersion: 2`，保留现有字段并新增 Cloudflare 分发字段。

保留字段：

- `platform`
- `versionName`
- `versionCode`
- `releaseTag`
- `apkAssetName`
- `apkSha256`
- `apkSize`
- `patches`

新增字段：

- `appId`
- `channel`
- `releaseId`
- `releaseNotes`
- `minClientVersionCode`
- `capabilities`
- `payloadSignature`
- `fullDownloadUrl`
- `fullFallbackUrl`
- `assets`

Patch 条目新增：

- `downloadUrl`
- `fallbackUrl`

客户端优先使用 patch `downloadUrl`，失败尝试 gated fallback endpoint。没有可用 patch 时使用 `fullDownloadUrl` 下载全量 APK。

Immutable Payload 签名：

- CI 对不可变 release security payload 签名，客户端内置公钥并验证 `payloadSignature`。
- 签名覆盖 appId、platform、versionName、versionCode、releaseTag、apkSha256、apkSize、patch hashes、asset hashes、minClientVersionCode、capabilities。
- `releaseNotes` 是后台可编辑的展示字段，不参与 CI security payload 签名；它必须作为纯文本转义显示，并由 audit log 记录修改历史。
- Worker 可包装 channel、短期下载 URL、releaseNotes 和 revision，但不得伪造已签名的文件完整性 payload。
- 静态 emergency manifest 也必须签名。

Public latest API 参数：

- `appId`
- `platform`
- `channel`
- `versionCode`
- `schemaVersion`
- `capabilities`

缺少 `schemaVersion` / `capabilities` 时，Worker 默认返回 v1-compatible manifest 或 no-update，不能返回 v2-only 字段给旧客户端。

## Android Client Update UX

- 保持每天启动自动检查一次。
- 手动点击“检查更新”不受每日限制。
- 更新界面需要像常规软件更新界面一样展示阶段和进度条。
- 检查阶段显示读取本机版本、获取更新清单。
- 发现新版本弹窗显示版本号、包类型、大小、release notes。
- 下载阶段显示进度条、百分比、已下载/总大小。
- 校验阶段显示正在校验安装包。
- 增量合成阶段显示合成新版安装包进度。
- 安装阶段显示正在打开系统安装器。
- 失败阶段提供重试、改用全量包、稍后等操作。
- 全量 fallback 前先弹窗说明原因、大小和 Wi-Fi 建议。
- 全量 APK 必须校验 `apkSha256` 后再调用现有 `installApk` MethodChannel。
- 全量 APK 下载写入唯一临时文件，失败时删除，sha256 通过后再 rename/安装。
- Patch 应用前限制最大 patch 文件大小、最大 manifest length、最大 operation count、非负 offset、合法 length 和 expected output size。
- 旧客户端不支持 Manifest v2 时继续走 v1/GitHub 兼容路径，直到新客户端覆盖足够版本。

## Release Notes

- Manifest v2 增加 `releaseNotes`。
- CI 可提供默认 release notes，但它不是 security payload 的一部分。
- 后台发布前允许编辑 release notes。
- 发布到 stable/beta 时要求 release notes 非空。
- 客户端只显示纯文本 release notes。
- 不做 Markdown 或 HTML 渲染。

## R2 Object Keys

采用版本化对象路径，不覆盖历史对象：

```text
trace/releases/{versionCode}-{releaseTag}/android/ble-monitor-android.apk
trace/releases/{versionCode}-{releaseTag}/android/patches/{fromVersionCode}-{oldShaPrefix}-to-{versionCode}.tpatch
trace/releases/{versionCode}-{releaseTag}/windows/ble-monitor-windows.zip
trace/releases/{versionCode}-{releaseTag}/windows/ble-monitor-windows.exe
trace/releases/{versionCode}-{releaseTag}/manifest/ble-monitor-update.json
```

latest 不作为 R2 物理对象路径，由 Worker/D1/KV 动态解析。

## R2 Retention

- R2 只保留最近 5 个 release 的完整资产和补丁。
- GitHub Release 保留完整历史备份。
- 清理规则保护当前 stable、当前 beta 和最近 5 个 release。
- 被清理的 R2 对象在 D1 中标记为 `r2_deleted` 或 `archived`。
- 旧版本需要回滚但 R2 已清理时，从 GitHub Release fallback 恢复或走 GitHub 下载。
- 后台禁止直接回滚到 `r2_deleted` / `archived` release；必须先从 GitHub Release 恢复 R2 asset 并校验 sha256，或显式选择 GitHub gated fallback-only 模式。

## Download Handling

- Manifest 返回 Worker 下载 URL。
- Worker 通过 R2 binding 读取对象并流式返回。
- 不直接暴露 R2 public URL 作为主 URL。
- GitHub Release fallback 只能使用 approved release 的 immutable tag-specific URL，并且必须通过 Worker redirect endpoint gate。
- Worker 下载响应设置 `Content-Type`、`Content-Length`、`ETag`、`Cache-Control`、`Content-Disposition`。
- Worker 不把大文件读入内存，直接返回 `object.body`。
- Manifest 和签名下载 URL 响应使用 `no-store` 或极短 `max-age`；只有 content-addressed immutable asset 响应使用长期缓存。
- 每次下载都重新检查 D1 release/asset/channel 状态，避免旧签名 URL 绕过禁用。
- D1 状态检查失败时 fail closed，返回稳定 errorCode，不绕过 revocation。

Public API error contract：

- `NO_UPDATE`：200，当前无可用更新。
- `CHANNEL_STOPPED`：200 或 503，渠道停更/维护中。
- `CLIENT_TOO_OLD`：426，客户端需要先安装兼容版本。
- `TOKEN_EXPIRED`：401，下载 token 过期。
- `TOKEN_INVALID`：401，下载 token 无效。
- `ASSET_DISABLED`：410，资产或 release 已禁用。
- `ASSET_ARCHIVED`：409，R2 资产已归档且未恢复。
- `RATE_LIMITED`：429，请求过快。
- `BACKEND_UNAVAILABLE`：503，D1/R2/Worker 状态检查不可用。
- `FALLBACK_UNAVAILABLE`：502，GitHub gated fallback 不可用。

## Stats

- 使用轻量统计方案。
- 下载请求不逐次写入 D1。
- Worker 输出结构化日志，字段包括 `event`、`appId`、`platform`、`channel`、`releaseId`、`assetId`、`assetType`、`status`、`bytes`。
- 首版后台可显示 Cloudflare Analytics 可提供的请求量/错误趋势，或先保留统计卡片占位。
- 后续如需落库，只写聚合表 `asset_daily_stats(asset_id, date, downloads, bytes, errors)`。
- 禁止每次下载插入 D1 明细。
- Worker 日志必须包含 requestId、releaseId、assetId、channel、status、errorCode。
- 增加 health check 和 asset integrity check：检测 current channel manifest、R2 object HEAD、sha256 metadata、GitHub fallback URL。
- 后台显示 broken manifest、缺失 R2 object、下载错误率升高等基础告警状态。
- 对 D1 read/error spike、download 4xx/5xx spike、asset integrity failure、rollback/stable publish 事件配置基础告警或后台红色状态。

## Admin Console

首版页面：

- Dashboard：当前 stable/beta、最近 candidate、异常提示。
- Releases：版本列表，筛选 candidate/published/superseded/disabled。
- Release Detail：资产、补丁、sha256、release notes、发布到 stable/beta、回滚、禁用、manifest 预览。
- Audit Logs：后台和 CI 操作记录。

必须二次确认的操作：

- 发布到 stable。
- 回滚 stable。
- 发布到 beta。
- 回滚 beta。
- 禁用 release。
- 禁用 asset。
- 清理 R2 旧资产。

Release Detail 提供 manifest 预览：

- 预览该 release 作为 stable 的 manifest。
- 预览该 release 作为 beta 的 manifest。
- 查看当前 stable 实际 manifest。
- 查看当前 beta 实际 manifest。
- 复制 JSON。

## Technology

目录放在本仓库：

```text
cloudflare/update-service/
  worker/
    src/
    test/
    wrangler.jsonc
  admin/
    src/
    public/
    package.json
  migrations/
    0001_init.sql
  scripts/
    register-release.mjs
  docs/
    README.md
```

Worker：

- Cloudflare Workers
- Hono
- TypeScript
- D1 prepared statements
- R2 binding
- KV binding
- 不使用 ORM

Admin：

- Vite
- React
- TypeScript
- Cloudflare Pages

CI/R2 upload：

- 统一使用一种上传路径，优先 R2 S3 API。
- S3 client 使用 `region: auto`。
- 大文件支持 multipart。
- 上传时写入 expected SHA-256 object metadata；multipart ETag 不得当作 SHA-256。
- 上传后执行 HEAD 校验 content length 和 SHA-256 metadata；必要时执行 read-back hash。
- D1 registration 拒绝缺失、size 不匹配或 sha256 不匹配的 asset。

Environments：

- 定义 `dev`、`staging`、`prod` wrangler env。
- 每个环境使用独立 D1 database、R2 bucket、KV namespace、Access audience、HMAC key 和 CI token。
- Pages admin 显示明显环境 banner。
- CI 只有 tag/explicit publish 可以写 prod；PR/push 只能写 dev/staging 或 artifacts。

Tests：

- Worker 必须覆盖 CAS conflict。
- disabled release 不可见且不可下载。
- GitHub gated fallback 必须检查 D1 状态。
- R2 archived release 回滚必须被拒绝或要求恢复。
- v1/v2 client compatibility。
- expired/invalid token。
- channel stop switches。
- D1 failure fail-closed。
- releaseNotes 编辑不破坏 payload signature。

## Cost Strategy

- 目标是正常个人使用尽量 0 成本。
- 超出免费额度或遭遇滥用时，允许手动降级/止血。
- 不使用 PostgreSQL。
- 不做高频 D1 写入。
- 不做付费统计链路。
- R2 是主下载源，但 GitHub Release 保留 fallback。
- 通过 R2 保留最近 5 个 release 控制存储。
- 通过短期签名下载、Durable Object 粗限速、缓存和紧急停更降低滥用风险。
- 在没有自定义域名前，WAF/Rate Limiting 不作为唯一防线；依赖 Worker-side 粗限速、短期签名、紧急停更和 GitHub emergency fallback。
- Worker-side 限速首选 Durable Object；KV 只用于粗粒度全局开关和缓存，不作为高频限速计数器。

## Backup

- 首版增加最小自动备份：定期 `wrangler d1 export --remote`，备份到 GitHub Actions artifact 或 R2 备份前缀。
- D1 schema 通过 migrations 版本管理。
- 资产完整历史保留在 GitHub Release。
- R2 只保留近 5 个 release。
- 后台关键操作写入 `audit_logs`。
- D1 可依赖 Cloudflare Time Travel 做短期恢复。
- audit logs 只允许 append，不提供 update/delete route，记录 before/after JSON、requestId、actor、ip、userAgent。

## Emergency And Secret Rotation

- 紧急停更拆分为 `disable_latest`、`disable_downloads`、`maintenance_admin_only`。
- Cloudflare 不可用时使用 GitHub 上的签名 emergency manifest，只指向最后确认的 known-good stable tag asset。
- Emergency manifest 使用客户端硬编码的稳定 URL，例如 `https://raw.githubusercontent.com/<owner>/<repo>/stable-emergency/trace-emergency-update.json` 或等价固定地址。
- Emergency manifest URL 可以更新内容，但客户端必须通过同一公钥验证 payload signature，并执行 versionCode 单调更新检查；签名无效或版本回退时拒绝使用。
- HMAC key、CI deploy token、R2 credentials、metadata signing key 都必须有 key version。
- Worker 接受当前 key 和上一个 key 的短过渡期，支持无停机轮换。

## Out of Scope

- PostgreSQL。
- Windows 应用内自动更新。
- 复杂多用户权限系统。
- 百分比灰度、地区灰度、设备白名单。
- 每次下载写入 D1。
- Markdown/HTML release notes。
- 复杂统计大屏。
- 自定义域名，等后续有域名再切换。

## Implementation Progress

### Phase 0 — code-complete on 2026-06-28

Implemented:

- GitHub Release safety: ordinary branch `push` no longer enters the formal GitHub Release job. Formal releases require a `v*` tag push or explicit `workflow_dispatch publish_release=true`.
- Manual formal releases now require an explicit `release_tag` unless the workflow runs on a tag, preventing generated `build-*` tags from becoming GitHub latest.
- Android release signing gate: the Android job exposes whether fixed signing secrets were configured, and the formal release job fails closed when fixed signing is absent. This also becomes the gate future Cloudflare candidate registration must reuse.
- Android client manifest compatibility: the update service now supports Manifest v1/v2 parsing, `schemaVersion` and `capabilities` negotiation for Cloudflare latest, `minClientVersionCode`, public API `errorCode`, release notes as pure text, and payload signature metadata.
- Cloudflare primary and fallback behavior: when `TRACE_CLOUDFLARE_UPDATE_MANIFEST_URL` is configured, the client does not fall back to GitHub `/latest/download`; it may use the fixed emergency manifest URL and manifest-provided gated fallback URLs. The legacy GitHub latest manifest path is retained only when no Cloudflare manifest URL is compiled into the app.
- GitHub asset fallback safety: v1 patch/full URLs are derived from `releaseTag + assetName` as immutable `releases/download/{tag}/{asset}` URLs instead of `/latest/download`.
- Full APK fallback: missing patch, failed patch download, failed patch hash, failed synthesis, or user choice can switch to full APK download. The full APK path uses a unique `.part` file, deletes failed partials, verifies `apkSha256`, renames only after verification, and then calls the existing `installApk` MethodChannel.
- Update UX: progress now shows checking, download percentage and bytes, verification, synthesis, installation, and failure dialogs with retry/full/later choices.
- Patch parser safety: the client now enforces maximum patch size, maximum patch manifest length, maximum operation count, positive operation lengths, non-negative copy offsets, copy range bounds, maximum output APK size, and exact output size matching before final SHA-256 verification.
- Emergency manifest prerequisites: the client supports a fixed `TRACE_EMERGENCY_UPDATE_MANIFEST_URL`, requires `payloadSignature` for emergency manifests, verifies Ed25519 signatures when `TRACE_UPDATE_PAYLOAD_ED25519_PUBLIC_KEY_BASE64` is compiled in, and rejects non-monotonic versionCode through the normal version comparison path.

Remaining risks:

- Phase 0 has not created or deployed Cloudflare Worker/D1/R2/KV/DO/Pages resources. Production Cloudflare setup remains blocked until account/token/domain/access details are explicitly provided.
- The exact CI/Worker canonical signature payload must stay aligned with the client's canonical JSON payload before signed v2 or emergency manifests are published.
- GitHub Actions must verify the workflow expression behavior for tag push, branch push, pull request, and manual publish paths because local workflow execution was not performed.
- Existing deployed old clients still read GitHub `/latest/download/ble-monitor-update.json`; operators must ensure current GitHub latest points only to manually approved stable releases before releasing the Cloudflare-capable client.

Validation:

- Local build/package verification was intentionally not run, per `AGENTS.md`.
- Local static Flutter/Dart validation could not be run because `flutter`/`dart` were not available in the local PATH.
- `git diff --check` was run and reported no whitespace errors, only line-ending warnings.
- `flutter pub get` could not run locally for the same PATH reason; `pubspec.lock` was updated from the official `pub.dev` package metadata for `cryptography` 2.9.0.
- Required external validation: run the GitHub Actions workflow for a branch push, a `v*` tag push, a manual `publish_release=false`, and a manual `publish_release=true + release_tag`; confirm only the allowed cases create formal GitHub Releases and that missing fixed Android signing fails the release job.

### Phase 1 — scaffold and GitHub Actions verified on 2026-06-28

Implemented:

- Added `cloudflare/update-service/` with Worker, D1 migration, admin placeholder, CI registration script, package metadata, generated Wrangler Env binding types, and local documentation.
- Added Worker public routes for `/api/public/latest`, `/api/public/download`, and `/api/public/github-fallback`.
- Public latest decisions are read from D1 `channels` and `releases`; unversioned channel state is not cached in KV.
- Manifest render cache uses the required revision-keyed KV key shape: `manifest:{appId}:{platform}:{channel}:{revision}`. The cache stores v1/v2 render envelopes so old and new clients can share the same revision key without returning v2-only fields to v1 clients.
- Phase 1 download and GitHub fallback endpoints both require short-lived HMAC tokens and re-check D1 release, asset, channel, and stop-switch state before redirecting to immutable GitHub tag asset URLs.
- The Worker rejects `/latest/download` GitHub asset URLs during CI candidate registration and the D1 schema also has a `release_assets.github_url` check constraint against `/latest/download/`.
- Added a Durable Object `RateLimiter`; KV is not used as a high-frequency rate-limit counter.
- Added CI `/api/ci/releases` candidate registration with bearer deploy token hash verification, formal release intent requirement, fixed Android signing requirement, immutable GitHub URL validation, idempotency by release tag/run id/commit, and candidate-only inserts.
- Direct Worker admin mutation routes are disabled. Internal publish/edit/disable functions exist for tests and future Access-protected Pages Functions integration, but are not exposed as public admin routes on `*.workers.dev`.
- Added D1 migration with `apps`, `app_config`, `releases`, `release_assets`, `patches`, `channels`, `channel_history`, and `audit_logs`.
- Migration includes foreign keys, `ON DELETE` strategies, enum `CHECK` constraints, Android `UNIQUE(app_id, platform, version_code)`, asset/channel/patch/history/audit indexes, channel disabled-release guard triggers, CAS revision-compatible channel update triggers, and append-only triggers for `channel_history` and `audit_logs`.
- Added invariant tests covering CAS conflict, disabled release invisibility/download rejection, gated GitHub fallback D1 checks, archived rollback rejection, v1/v2 compatibility, token failure, stop switches, D1 fail-closed behavior, and releaseNotes/signature separation.
- Added a GitHub Actions workflow for `cloudflare/update-service` that runs `npm ci`, Env-only Wrangler type generation, `tsc --noEmit`, and Worker invariant tests on Linux without deploying Cloudflare resources.
- Fixed the initial Linux invariant failures by using `UPDATE ... RETURNING` for CAS success detection, preventing test fetches from following fake GitHub redirect targets, and verifying D1 fail-closed behavior through the Worker/Hono error handler.
- Added staging setup automation and operator documentation: `bootstrap-staging.ps1`, `bootstrap-staging.mjs`, and `docs/STAGING-SETUP.md`. The bootstrap is staging-only, requires explicit `--yes`, creates/reuses D1/KV/R2, updates non-secret Wrangler IDs, applies migrations, deploys staging Worker, writes Worker secrets, and smoke-tests `/healthz` plus public latest.

Remaining risks:

- No real Cloudflare D1/KV/R2/DO/Pages resources were created, no Access application was configured, and no production deployment was performed.
- The new staging bootstrap has not been run against a real Cloudflare account in this repository session because no account ID or API token was provided.
- Worker runtime tests still cannot execute locally because Miniflare/workerd crashes on this Windows host with `0xc0000005` access violation before running test files. The same local runtime crash affected full `wrangler types`; Env-only `wrangler types --include-runtime false` succeeds. Linux GitHub Actions is the runtime verification path for this host.
- Admin mutation placement still needs the planned Access-protected Pages Functions facade before any real admin operations are enabled.
- Phase 1 still uses immutable GitHub tag assets as the actual file source. R2 upload, R2 streaming, retention, and restore workflows remain Phase 2+.
- The generated CI security payload canonicalization must be verified against the Android client's `_canonicalJson` before publishing signed v2 or emergency manifests.

Validation:

- `npm install` was run in `cloudflare/update-service/worker` to create `package-lock.json`.
- `npm run cf-typegen` succeeded after switching to Env-only generation with `wrangler types --include-runtime false worker-configuration.d.ts`.
- `npm run check` succeeded with `tsc --noEmit`.
- `npm run check` was re-run after the CAS/test-harness fixes and passed.
- `npm test` was attempted twice locally but blocked before test execution by local Miniflare/workerd `0xc0000005` access violation.
- GitHub Actions `Cloudflare Update Service Checks` passed on Linux for commit `ab44e6e`: `https://github.com/Eitan-S-23/Trace/actions/runs/28325141952`. The run completed `npm ci`, `npm run cf-typegen`, `npm run check`, and `npm test`.
- GitHub Actions `Build APK and EXE Release` passed for commit `ab44e6e`: `https://github.com/Eitan-S-23/Trace/actions/runs/28325141953`. Android APK, Windows EXE/zip, and Pages jobs passed; the formal GitHub Release job was skipped on branch push.
- Staging bootstrap validation was limited to static/syntax checks and dry-run/help invocation. No real Cloudflare resource creation, migration, secret write, or deploy was executed.
- Local build/package commands were not run.

### Phase 1 follow-up — staging deployment and CI candidate registration wiring on 2026-06-29

Implemented:

- Staging bootstrap output is now explicitly ignored via `cloudflare/update-service/.bootstrap/`, so local summary files containing raw deploy tokens are not committed.
- The staging Worker/D1/KV/R2 IDs produced by bootstrap are recorded in `cloudflare/update-service/worker/wrangler.jsonc`; production bindings remain placeholders.
- Added `cloudflare/update-service/scripts/build-github-release-metadata.mjs`, which derives Cloudflare candidate metadata from the GitHub Release assets, validates APK/patch SHA-256 and sizes, emits immutable GitHub tag asset URLs, and prepares the `/api/ci/releases` payload.
- The formal GitHub Release job now compiles Android with `TRACE_CLOUDFLARE_UPDATE_MANIFEST_URL=${TRACE_UPDATE_SERVICE_URL}/api/public/latest` when the repository secret is present.
- After uploading GitHub Release assets, the formal release job generates Cloudflare metadata and calls `register-release.mjs` with `TRACE_UPDATE_SERVICE_URL` and `TRACE_DEPLOY_TOKEN`.
- Ordinary branch pushes and pull requests still do not create formal GitHub Releases and still cannot register Cloudflare candidates.
- Staging documentation now explains bootstrap, GitHub Secrets, candidate registration verification, and the current publish boundary.

Remaining risks:

- A real Ed25519 payload signing key is not configured yet. CI currently uses an explicit staging-only placeholder `payloadSignature` for candidate registration; those candidates must not be published to clients until real signing and the matching client public key are configured.
- Access-protected admin mutation placement is still not implemented, so candidates remain invisible to `/api/public/latest` until a safe Pages Functions facade or equivalent Access-protected entry is added.
- R2 primary upload/download remains Phase 2; Phase 1 candidates still point to immutable GitHub tag assets through Worker-gated download URLs.
- A formal GitHub Actions release run still needs to verify the full GitHub Release upload -> Cloudflare candidate registration path against staging.

Validation:

- `node --check cloudflare/update-service/scripts/build-github-release-metadata.mjs` passed.
- `node --check cloudflare/update-service/scripts/register-release.mjs` passed.
- `node --check cloudflare/update-service/scripts/bootstrap-staging.mjs` passed.
- A synthetic metadata generation run using temporary dummy release assets succeeded and produced the expected candidate payload shape.
- `npm run check` passed in `cloudflare/update-service/worker`.
- `git diff --check` passed with only line-ending warnings.
- `npm test` remains blocked locally by the known Windows workerd `0xc0000005` runtime crash before tests execute.
- Local Flutter/Gradle build/package commands were not run.

### Phase 1 follow-up — Access admin facade and payload signing wiring on 2026-06-29

Implemented:

- Added `cloudflare/update-service/admin` as the Phase 1 Pages Functions admin facade. It is a minimal API surface, not the final React console.
- Direct Worker `/api/admin/*` remains disabled. Admin mutations are implemented only under the Pages Functions same-origin facade.
- Added Access JWT verification for the admin facade: issuer, audience, expiry, optional `nbf`, RS256 signature via Cloudflare Access JWKS, email allowlist, and role derivation.
- Added role gates: `viewer` can list session/channels/releases, `publisher` can edit release notes and publish/rollback beta, and `owner` can publish/rollback stable or disable unpublished releases.
- Added same-origin `Origin` enforcement and CSRF double-submit token for all admin mutations.
- Added admin endpoints for session, channel listing, release listing, publish/rollback, release note edits, and disabling unpublished releases.
- The admin facade publishes channels through D1 CAS revision updates and uses existing triggers for `channel_history` and append-only `audit_logs`.
- Added `generate-payload-signing-key.mjs` to create an Ed25519 PKCS#8 private key for CI and a raw 32-byte public key for the Flutter client.
- GitHub Actions now passes `TRACE_UPDATE_PAYLOAD_ED25519_PUBLIC_KEY_BASE64` into Android builds when configured, and passes `TRACE_UPDATE_PAYLOAD_ED25519_PRIVATE_KEY_BASE64` plus `TRACE_UPDATE_PAYLOAD_KEY_VERSION` into Cloudflare candidate metadata generation.
- Cloudflare checks now typecheck both the Worker and the Pages admin facade.

Remaining risks:

- The admin Pages project has not been deployed because the Cloudflare Access application issuer, audience, and role email lists are account-specific and must be configured first.
- The Access admin facade has not been runtime-tested against a real Access JWT yet.
- GitHub repository secrets for real payload signing still need to be generated and configured before any candidate is published to phones.
- There is still no final admin React UI; current operations use the JSON API.
- R2 primary distribution remains Phase 2.

Validation:

- `npm install` was run in `cloudflare/update-service/admin` to generate `package-lock.json`.
- `npm run check` passed in `cloudflare/update-service/admin`.
- `npm run check` passed in `cloudflare/update-service/worker`.
- `node --check cloudflare/update-service/scripts/generate-payload-signing-key.mjs` passed.
- `node --check cloudflare/update-service/scripts/build-github-release-metadata.mjs` passed.
- `generate-payload-signing-key.mjs` was run with output redirected to a temporary file and removed; its internal sign/verify self-check passed.
- `git diff --check` passed with only line-ending warnings.
- `npm test` was attempted in `cloudflare/update-service/worker` and remains blocked before test execution by the known Windows workerd `0xc0000005` runtime crash.
- Local Flutter/Gradle build/package commands were not run.
