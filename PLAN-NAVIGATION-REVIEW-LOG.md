# Plan Review Log: GPX Route Navigation

Act 1 (grill) complete - plan locked with the user. MAX_ROUNDS=5.

## Round 1 - Codex

Review could not complete. `codex exec -s read-only --json` started thread
`019f19b6-c6c3-7011-9f30-16e6a880ff0d`, then failed with repeated
`401 Unauthorized: Invalid token` responses from the configured provider.

No Codex verdict was produced.

## Resume attempt - Codex CLI still blocked

`codex --version` returned `codex-cli 0.142.3`, satisfying the version requirement.

A direct retry with the normal user `CODEX_HOME` failed before thread startup because the CLI could not initialize its in-process app-server client:

```text
Error: failed to initialize in-process app-server client: access denied (os error 5)
```

The apparent cause is that this agent session cannot write `C:\Users\SU\.codex\tmp\arg0`, which the Codex CLI uses for temporary arg0 state. `--ephemeral` did not avoid that write.

A temporary workaround using a workspace-local Codex HOME allowed the CLI to start a thread:

```text
thread_id=019f1dba-36d6-7582-9cf4-833eeca7ff44
```

However, the turn still failed before producing a verdict file. A minimal non-review test also failed with:

```text
stream disconnected before completion: builder error
```

The temporary workspace-local Codex HOME was removed after clearing copied auth/config files. No Codex verdict was produced; Act 2 remains blocked by the external Codex CLI/runtime, not by the navigation plan content.

## Round 2 - 本地对抗审查（Codex 不可用时的替代评审）

Codex CLI 跨会话复现同一运行时故障：`codex exec -s read-only` 启动线程后，custom provider（gpt-5.5）反复 `Reconnecting 1..5/5` 并以 `stream disconnected before completion: builder error` 失败，最小非评审用例同样失败。确认为外部 provider/运行时问题，非计划内容问题。为不无限阻塞，改由本地 AI 扮演对抗审查者，将计划逐条对照真实代码核验。

### 现状核验（计划对现状的描述准确）
- `USER\App\Common\DataProc\DP_Navigation.cpp:10,40`：`#define NAV_ROUTE_POINT_MAX 768` + `static Navigation_RoutePoint_t routePoints[768]` 常驻数组，属实。
- 同文件 `:485,499`：GPX 导入直接用 `lv_fs_open/lv_fs_read`，属实。
- 同文件 `:744,782`：`Navigation_QueryRouteWindow` 现直接读常驻 `routePoints`，属实。
- `Simulator\...\lvgl\src\misc\lv_fs.h:73-84`：`lv_fs_drv_t` 仅有 ready/open/close/read/write/seek/tell/dir_open/dir_read/dir_close，确实**没有** remove/rename/trunc/sync 回调 → 计划要求 `NavigationCacheFS` 成立。
- `USER\App\Utils\StorageService\StorageService.cpp:227`：`FileWrapper file(path, LV_FS_MODE_WR | LV_FS_MODE_RD)` 不截断，写更短 JSON 会残留旧尾字节，属实。
- `DataProc_Def.h:107-110`：NAV_PATH_MAX=256 / NAME=48 / WP=32 / CUE=32 已按计划定义。
- `Navigation_Info_t`（`DataProc_Def.h:176-195`）为紧凑快照，无路线数组，符合计划。

### 发现（按严重度）

**[阻断-1] 100000 点上限与既有 `uint16_t` 索引直接矛盾。**
`Navigation_Info_t.pointCount` 为 `uint16_t`（`DataProc_Def.h:190`），`Navigation_RouteWindowQuery_t.startIndex/stride`、`Navigation_RouteWindowResult_t.written/nextIndex/totalCount` 全为 `uint16_t`（`:216-227`）。最大只能寻址 65535 点。计划 §8 定 on-SD 上限 100000，且 §1/§15 要求"保留 `Navigation_QueryRouteWindow` 这个直接 API"。两者不能同时成立。必须二选一：(a) 把首版上限降到 ≤65535 并在计划中写死；或 (b) 把 `pointCount`/window 索引全部拓宽为 `uint32_t`——这会改动已发布快照结构与 LiveMap/Dialplate 所有消费者，属破坏性改动，需在计划 §1/§8/§15 显式列出。计划当前未提。

**[阻断-2] StorageService 修复方案的兜底本身在当前 LVGL FS 上不可用。**
计划 §18："修复 SaveFile 避免残留尾字节。优先 temp-write/replace；若不可用，则 truncate/sync"。但本 LVGL FS 既无 `rename_cb`（temp-replace 不可行）也无 `trunc_cb`（truncate 不可行），两条路都断。结论：StorageService 的修复**必须**同样走 `NavigationCacheFS`/SdFat 原生路径（或按定长补齐），计划 §18 需把这一依赖写明，删除"truncate/sync"这个不可达兜底。

**[重要-3] 两阶段提交依赖的 rename/replace 在 FatFs 上非原子，掉电恢复未定义。**
计划 §5 "replace/rename 到 .nav；替换失败则保留旧缓存不变"。FatFs `f_rename` 目标已存在时会失败，需先删旧 `.nav` 再 rename tmp→.nav，此过程非原子；若在"删旧后、rename 前"掉电，则新旧皆失。计划需补：保留 `.tmp` 直到 rename 确认成功；启动时若 `.nav` 缺失但存在校验通过的 `.tmp` 则提升为 `.nav`。当前 §5/§13 未覆盖此恢复路径。

**[重要-4] 浏览路径（LVGL '/' 盘符）与 NavigationCacheFS '/Navigation' 根之间的路径契约未定义。**
`RouteSelect` 用 LVGL FS 浏览、命令里传 `/Navigation/foo.gpx`（§4/§5），而 `DP_Navigation` 之后必须改用 `NavigationCacheFS` 打开同一路径（§3）。LVGL 会剥离首字符、SdFat 直收真实路径（AGENTS.md 已记此坑）。计划需显式规定：命令中的逻辑路径首 '/' 如何映射到 NavigationCacheFS 根，两套路径约定如何对齐，且 GPX 打开必须经 NavigationCacheFS 而非 LVGL FS，否则设备端"无法打开目录/文件"类问题会重现。

**[次要-5] `Navigation_QueryRouteWindow` 无视口/bbox 参数，与 §9/§15 的 bbox 驱动预览存在张力。**
现有 API 仅 startIndex+stride（`:213-218`）。§9 想让预览按 index-bbox 选候选页，§15 又要求"保留该 API"。对 10 万点路线，固定 stride 只是粗抽稀，无法按视口裁剪。需在计划中明确：要么承认 v1 预览为 stride 抽稀（可接受但写明），要么扩展查询结构加入 bbox/viewport（与"保留 API"冲突，需注明为破坏性扩展）。

### 结论
计划整体扎实、对现状描述准确，但存在 **2 处阻断级**问题（uint16_t 上限矛盾、StorageService 兜底不可达）在开工前必须修订，另有 2 处重要缺口（非原子 rename 恢复、路径契约）和 1 处次要张力（预览 API）。建议：**退回小修**——按上述 5 点更新 PLAN-NAVIGATION.md 的 §1/§5/§8/§13/§15/§18 后再进入实现。这些均为具体、可落实的条款修订，不动整体架构。

### 处置（已应用到 PLAN-NAVIGATION.md）
- [阻断-1] 已定：路线点上限降到 `65535`，保留全部既有 `uint16_t` 索引，零破坏性；超限导入报"路线过长"。§8 与 Key Decisions 已改，`uint32_t` 拓宽列为 v1 范围外。（用户拍板）
- [阻断-2] §18 已改：删除不可达的 LVGL-FS truncate 兜底，改为经 `NavigationCacheFS`/SdFat 的 temp-write+remove/rename，或定长补齐。
- [重要-3] §5 已补：FatFs `f_rename` 非原子，采用"校验 .tmp → 删旧 .nav → rename"，启动恢复可把校验通过的残留 `.tmp` 提升为 `.nav`。
- [重要-4] §3 已补：浏览路径（LVGL 剥离首字符）与 `NavigationCacheFS` `/Navigation` 根的映射契约，GPX/.nav 一律经 NavigationCacheFS 打开。
- [次要-5] §15 已注：v1 预览为 stride 抽稀（无 bbox），视口精确预览属破坏性 API 扩展、后续再议。

Round 2 结束：阻断项已清零，计划可进入实现阶段。Codex 独立复核仍待其运行时恢复后补做。