# Plan: GPX Route Navigation
_Locked via grill-me discussion - Codex + user_

Status: revised after implementation audit. This file is the implementation source of truth. The existing RouteSelect, RouteImport, MainMenu, LiveMap, and Dialplate page/data-flow work should be preserved; the current in-RAM `routePoints[768]` route implementation is not the target architecture and must be replaced by SD-backed `.nav` cache paging.

## Goal
Implement GPX-based route navigation for the existing AT32F435 `LiveMap` and Dialplate UI. The user selects a `.gpx` from `/Navigation`, imports it into a validated SD-card `.nav` cache, previews the route on `LiveMap`, explicitly starts/stops navigation, and receives consistent route-derived guidance on `LiveMap` and Dialplate. Route data must be SD-backed and paged so MCU RAM use stays bounded even for large GPX files.

## Approach
1. Keep the current page/data-flow shell, but replace the route data layer.
   - Preserve existing `RouteSelect`, `RouteImport`, MainMenu navigation settings, `LiveMap` navigation banner/route overlay, and Dialplate subscription flow.
   - Remove the current `DP_Navigation` dependency on a resident `routePoints[768]` array as the primary route store.
   - Remove direct GPX-to-RAM route import as a formal path. The import path must produce a `.nav` cache before a route can become valid.
   - `Navigation_Info_t` remains a compact snapshot. It must not contain route point arrays, full path staging buffers, or page caches.
   - Keep `Navigation_QueryRouteWindow(...)` as the direct route-window service API, but implement it over `.nav` cache paging rather than over resident route arrays.

2. Define fixed limits and ownership contracts.
   - Use `NAV_PATH_MAX = 256`, `NAV_ROUTE_NAME_MAX = 48`, `NAV_WAYPOINT_NAME_MAX = 32`, and `NAV_CUE_TEXT_MAX = 32`, all as UTF-8 byte limits including trailing NUL.
   - GPX path, cache path, route name, and core cue text must be validated before copy. Over-length critical fields fail with Chinese errors such as "路径过长" or "名称过长"; do not silently truncate and continue.
   - Waypoint names are non-critical: if a waypoint name exceeds `NAV_WAYPOINT_NAME_MAX`, truncate at a valid UTF-8 boundary, set a warning/status, and continue import.
   - Every navigation command must copy owned payloads into `DP_Navigation` staging buffers before returning from `Notify(...)`.
   - Command payloads and published snapshots remain separate: commands use `Notify("Navigation", ...)`; consumers use `Pull("Navigation", ...)` and route-window query helpers.

3. Add a portable `NavigationCacheFS` abstraction.
   - Do not make `DP_Navigation` include or call SdFat, Win32, CRT, or platform-specific FS APIs directly.
   - `RouteSelect` may continue to use LVGL FS for browsing, but GPX import, source identity, `.nav` writes, sync, remove/rename commit, cache validation, and paged reads must use `NavigationCacheFS`.
   - The current LVGL FS is insufficient for `.nav` commit: the registered driver exposes open/read/write/seek/tell/dir callbacks only, and this LVGL version has no `remove_cb`, `rename_cb`, `trunc_cb`, or `sync_cb` fields.
   - Firmware backend: implement `NavigationCacheFS` with SdFat native APIs, including mkdir, exists, open, read/write, seek/tell/size, sync, close, remove, rename/replace, and truncate if needed.
   - Simulator backend: implement the same logical API with PC file APIs, mapping project `/...` paths to the simulator file root.
   - `NavigationCacheFS` paths use the same logical `/Navigation/...` convention across firmware and simulator.
   - Path-convention contract: `RouteSelect` browses through LVGL FS, where the
     leading drive character is stripped before the driver sees the path
     (`/Navigation/foo.gpx` reaches SdFat as `Navigation/foo.gpx`, `/` reaches
     it as an empty string that must normalize to root). Commands still carry
     the full logical `/Navigation/...` path, but GPX import, `.nav` writes,
     validation, and paged reads must open these paths through
     `NavigationCacheFS` (native SdFat / PC file APIs), never through LVGL FS.
     `NavigationCacheFS` is responsible for mapping the leading `/` to its own
     root identically on firmware and simulator, so the same logical path
     resolves the same file on both.
   - Add `GetFileInfo(path, size, mtime, hasMtime)`. mtime support is optional; if unavailable or unreliable, use a streamed source CRC32 for source identity.

4. Route selection starts at `/Navigation`.
   - `RouteSelect` should ensure/open `/Navigation` and start there.
   - If `/Navigation` cannot be created/opened, fall back to `/`, show a Chinese error, and keep the top path label synchronized with the actual `currentPath`.
   - The top path label must always reflect the real browser path during enter, back, root, fallback, and subdirectory navigation.
   - Show directories and `.gpx` files only; skip hidden entries and `System Volume Information`.
   - Use full LVGL-style logical paths in commands, e.g. `/Navigation/foo.gpx`.
   - Fix `RouteSelect` focus-group management: do not call `lv_group_remove_all_objs()` from a child page. Add/remove only objects owned by `RouteSelect`.

5. Import GPX into `.nav` with two-stage commit.
   - `RouteImport` owns only UI/timer stepping and progress display. `DP_Navigation` owns parser state, file handles, temp/final cache paths, source identity, warnings, validation, and commit state.
   - Selecting a GPX sends a copied select/import command and opens/replaces `RouteImport`; it does not start navigation.
   - During import/validation, `LiveMap` must not preview partial route geometry. It should show unavailable/loading state until the cache becomes `valid`.
   - Write `/Navigation/Cache/<basename>_<hash>.tmp`, close/sync, reopen and validate header/counts/CRC/source identity, then replace/rename to `/Navigation/Cache/<basename>_<hash>.nav`.
   - If replacement fails, preserve the previous selected route/cache unchanged.
   - FatFs `f_rename` is not atomic and fails when the destination exists, so
     the commit is: validate `.tmp` fully, then remove any old `.nav`, then
     rename `.tmp` -> `.nav`. Keep the validated `.tmp` on disk until the
     rename is confirmed. Because this remove+rename window is not power-safe,
     boot recovery must handle a missing `.nav` whose matching validated
     `.tmp` still exists by promoting that `.tmp` to `.nav`; a `.tmp` that
     fails validation is deleted as stale.
   - Clean stale `.tmp` files on boot or before import.
   - If an existing final cache matches source identity, format version, coordinate-system version, and CRC, reuse it; otherwise build a new temp cache first.

6. Cache naming and source identity.
   - Cache files live under `/Navigation/Cache/`.
   - Cache names are deterministic: `/Navigation/Cache/<basename>_<hash>.nav`.
   - Hash input uses normalized GPX path plus source size and reliable mtime when available.
   - If reliable mtime is unavailable, stream the GPX to compute source CRC32 and use normalized path + size + source CRC.
   - The `.nav` header records `hasMtime`, `mtime`, source size, source CRC if used, source path/name fields, and cache identity fields.
   - Display route name is not part of cache identity.

7. `.nav` file format.
   - Use magic `XNAV`, explicit format version, coordinate-system version, `headerSize`, flags, section offsets/counts, record sizes, route bounds, total distance, source identity, and CRC32.
   - Design the file as section-based and extensible: at minimum route point section, index section, cue candidate section, waypoint section, and optional future sections.
   - File byte order is little-endian. Use explicit `read_u16_le/read_u32_le/read_i32_le/write_*_le` helpers; do not rely on raw `fwrite(struct)` as the long-term file format.
   - Readers must respect `headerSize`, section offsets, counts, and record sizes. Unsupported versions or unsupported record sizes return a Chinese "路线缓存版本不支持" style error.
   - CRC32 covers the header with CRC field zeroed plus all known required sections. Full CRC validation is staged, not synchronous in UI paths.

8. SD cache size and RAM budget.
   - SD-card file size is not the primary constraint; MCU RAM and per-tick latency are.
   - First-version `.nav` on-SD route point cap is `65535` points. This bound is
     set by the existing published `uint16_t` route indexing (`Navigation_Info_t.pointCount`
     and the `Navigation_QueryRouteWindow` query/result `startIndex`/`stride`/`written`/
     `nextIndex`/`totalCount`), which is kept unchanged. Import of a GPX whose
     cleaned route exceeds `65535` points fails with a Chinese "路线过长" style
     error rather than silently truncating. Widening route indexing to
     `uint32_t` is a separate breaking change and is out of scope for v1.
   - Runtime RAM must not scale linearly with total route points. Keep only fixed page buffers, index/cue windows, current search state, and visible render buffers.
   - Define final page sizes and `sizeof` budgets in code before enabling long-route import. Fail cache load/start with Chinese error if resident buffers exceed safe RAM margin.
   - Do not keep full route geometry resident in `Navigation_Info_t`, `DP_Navigation`, `LiveMap`, or any `std::vector`.

9. Route index section.
   - Add a lightweight index record about every 256 route points.
   - Each index record stores `firstPointIndex`, `pointCount`, route point file offset, `startDistanceCm`, `endDistanceCm`, and lat/lon bbox.
   - Preview, matching, and acquisition scan index blocks first, then read candidate route point pages.
   - First acquisition may scan the whole route, but only incrementally by bounded index blocks/pages per timer tick.

10. GPX parser and geometry.
   - Implement a bounded streaming GPX tokenizer/parser; do not use Arduino `String` or heap-growing XML buffers.
   - Support chunk boundaries, attribute order variance, single/double quotes, optional XML namespace prefixes, and `<trkpt>`, `<rtept>`, `<wpt>`.
   - Route geometry uses `<trkpt>` when present, otherwise `<rtept>`.
   - `<wpt>` records are cached as waypoints and do not participate in route line or matching.
   - Parse lat/lon and useful optional fields such as elevation/time/name where supported.
   - Malformed GPX, invalid coordinates, or missing route geometry should return Chinese file-format errors.
   - Store one cleaned route point section for v1. Remove invalid points, exact duplicates, and obvious zero-length/near-zero noise, but do not aggressively simplify merely to save SD space.

11. Waypoints and route name.
   - Cache up to 512 waypoints in v1. If more are found, ignore overflow and publish a warning/status; do not fail the whole import.
   - Route display name priority: GPX metadata/name, then track/route name, then GPX file basename.
   - If a GPX internal name is empty or too long, fall back to basename. If basename exceeds `NAV_ROUTE_NAME_MAX`, fail with Chinese "名称过长".

12. Turn guidance.
   - Use a hybrid cue strategy.
   - During import, generate geometry-derived cue candidates and store them in the `.nav` cue section. These are candidate events, not street-name instructions.
   - At runtime, GPS matching determines current progress; `DP_Navigation` reads the forward cue window and chooses the next unpassed cue based on current progress and distance.
   - Runtime may verify cue type with nearby forward route points to reduce false positives.
   - This supports tight turns a few meters ahead, long straight sections, and stable performance without relying only on the immediate next point or a fixed lookahead distance.

13. Cache validation and restored selections.
   - Persist selected route/cache metadata, but never persist `active`.
   - On boot, a restored selected route starts as `selected_unvalidated`.
   - Validation first performs a quick header/source/version/count/record-size check, then enters `validating` and computes full CRC in bounded chunks.
   - Only full validation success publishes `valid`. MainMenu "开始导航" and LiveMap preview are disabled until `valid`.
   - Validation, route-window queries, matching, and CRC must never block LVGL frames.

14. Navigation state and matching.
   - User explicitly starts navigation from MainMenu; selecting/importing a route only stores and validates it.
   - States include inactive/no route, selected/loading/importing/validating, searching/approaching route, on route, off route, reverse direction, finished, and error.
   - First acquisition or lost progress may scan the whole route, but only incrementally by index blocks/pages.
   - After acquisition, search a forward-biased window around current progress; for loops/overlaps, prefer monotonic progress unless the user restarts guidance.
   - Use WGS84 route records for matching/guidance; `MapConv` is display-only.
   - GPS invalid: keep last safe guidance but publish "等待定位"; do not advance progress or trigger off-route/reverse/finish.
   - Low speed under about 2 km/h: allow distance updates but suppress off-route accumulation, reverse detection, and jitter-sensitive state transitions.
   - Off-route: enter after distance to route > 40 m for 2 consecutive GPS updates; clear below 25 m. If local matching fails repeatedly, re-enter incremental full-route acquisition.
   - Reverse detection: after acquisition and above low-speed threshold, if GPS course differs from route forward bearing by about 135 degrees for consecutive updates, show "路线方向相反"; auto-clear after consecutive normal direction updates. Do not auto-reverse the route.
   - Finish: final segment and within 30 m of route end for 2 valid GPS updates. Finished state is latched until user stops navigation, selects a new route, or restarts.

15. LiveMap route preview.
   - Draw route preview only when cache status is `valid`.
   - Route geometry is obtained through `Navigation_QueryRouteWindow(...)` using caller-owned fixed buffers.
   - The existing `Navigation_QueryRouteWindow(...)` signature carries only
     `startIndex` + `stride`, with no viewport/bbox parameter, so v1 preview is
     an index-strided subsample of the route, not a bbox-clipped selection.
     This is acceptable for v1. If viewport-accurate preview is later required,
     extending the query struct with a bbox/viewport is a breaking API change
     to a published contract and must be planned as such, not slipped in.
   - The query API returns `done`, `partial`, `busy`, `stale_revision`, or `error`; it must not retain caller buffers.
   - `LiveMap` tracks route revision/status, viewport, and zoom; route windows are rebuilt when needed and partial/busy paths do not block frames.
   - Convert WGS84 route points to map pixels via `MapConv`, then use bounded render buffers and the existing line/clip pattern. Do not insert all route points into any resident vector.
   - Keep route overlay separate from recorded track drawing.

16. LiveMap and Dialplate guidance UI.
   - Preserve the existing top navigation banner and Dialplate navigation data flow.
   - Update labels only when navigation values change.
   - UI may show inactive selected route, validating/importing, route ready, approaching, off-route, reverse, finished, and error states.
   - Avoid new `shadow_*`, custom draw callbacks, masks, `lv_draw_*`, or heavy animation/drawing paths.
   - Keep icon fonts and text fonts separate.

17. MainMenu navigation settings.
   - Keep current route/status, "选择路线", and start/stop action rows.
   - "选择路线" opens `Pages/RouteSelect`.
   - "开始导航" requires route status `valid`; disabled or shows Chinese error for no route, pending validation, import, invalid cache, or error status.
   - "停止导航" disables active guidance but keeps selected GPX/cache paths.
   - Touch and encoder click paths must route through the same action dispatcher.
   - Returning from `RouteSelect`/`RouteImport` must preserve deterministic navigation-settings flow and must not depend on ad-hoc pop payloads.

18. StorageService changes.
   - Add explicit-key storage registration or a navigation storage table. Do not use C expression text from `STORAGE_VALUE_REG(...)` for navigation keys.
   - Persist selected GPX path, selected cache path, route display name, source/cache identity, cache CRC/revision, and last error/status fields.
   - Store booleans/status as fixed-width integer fields.
   - Do not persist runtime `active`.
   - Fix `StorageService::SaveFile()` so shorter JSON writes cannot leave stale tail bytes. The current LVGL FS driver exposes no `rename_cb` and no `trunc_cb`, so neither temp-write/replace nor truncate works through LVGL FS. Route the fix through `NavigationCacheFS`/native SdFat (temp-write then the same non-atomic remove+rename recovery used by the `.nav` commit), or write the JSON followed by an explicit pad-to-previous-length so no stale tail survives. Do not rely on an LVGL-FS truncate that does not exist.
   - Audit/increase static JSON capacity and verify load/save with maximum navigation strings followed by shorter strings.

19. Chinese font and source string rules.
   - Before adding new Chinese text, verify required glyphs against `USER\App\Resource\Font\font_cn_16.c.chars`.
   - If glyphs are missing, regenerate the Chinese subset with `Tools\font_gen` and update `font_cn_16.c` / `.chars`.
   - Generate AC5-safe source string literals with `python Tools\font_gen\gen_font.py --cstr "<text>"` and put UTF-8 `\xNN` literals in C/C++ source files, not raw Chinese text.
   - If generated font source changes, ensure simulator and Keil project entries include affected files and rebuild relevant targets.

20. Build and verification.
   - Add every new source/header to both `Simulator/LVGL.Simulator/LVGL.Simulator.vcxproj` and `.filters`.
   - Add every new F435 source to `MDK-ARM_F435/proj.uvprojx`. New page/source groups using C++11 features need the same `--cpp11` group option as existing page groups.
   - If Keil dep/lnp files do not include a new source yet, use `MDK-ARM_F435/build_f435.ps1 -NewSources` and `-ExtraLinkObjs` as needed.
   - Verify RouteSelect browsing from `/Navigation`, fallback path display, directory filtering, and GPX selection path ownership.
   - Verify RouteSelect group handling does not break MainMenu focus after Pop/Replace.
   - Verify `.nav` temp-write failure, commit success, replacement failure preserving old selection, stale temp cleanup, checksum mismatch, source identity mismatch, unsupported version, SD removal/USB busy, and reboot restored-selection validation.
   - Verify long GPX import without resident full-route arrays, with point counts near the selected on-SD cap and with bounded RAM.
   - Verify waypoint overflow warning, over-length critical fields, malformed GPX, missing glyph handling, and route-name fallback.
   - Verify incremental validation and acquisition do not stall LVGL frames.
   - Verify LiveMap preview, top banner, off-route/approach/reverse/finish, and Dialplate display in simulator screenshots.
   - Build simulator first and inspect screenshots.
   - Build F435 firmware using the project guide and report Program Size, output timestamps, warnings, and errors.

## Key Decisions & Tradeoffs
- The current UI/data-flow work is preserved, but the current resident `routePoints[768]` route store is not the final architecture.
- Route data moves directly to `.nav` cache paging instead of first polishing the in-RAM MVP.
- `.nav` files may hold up to 65535 route points (bounded by the existing published `uint16_t` route indexing, kept unchanged); MCU RAM remains bounded by fixed page/window buffers.
- `NavigationCacheFS` is required for portability and safe commit; LVGL FS remains for browsing but is not sufficient for cache commit.
- Import completion is required before preview; no partial route preview from temp files.
- Cache names are deterministic and source-identity checked.
- `.nav` is section-based, little-endian, and explicitly serialized for portability.
- A lightweight index section is worth the small SD overhead because it keeps preview, acquisition, and matching bounded.
- Turn guidance uses imported cue candidates plus runtime current-position confirmation.
- Waypoint name truncation is acceptable with warning; critical path/name/cue fields fail on over-length input.
- Route display name may come from GPX metadata, but cache identity never depends on display name.
- GPS invalid/low-speed conditions suppress dangerous state transitions to avoid jitter.
- Reverse route navigation is out of scope; reverse travel only warns.
- Finished state is latched.
- Chinese font generation and AC5-safe string literals are part of the implementation contract.

## Risks / Open Questions
- Exact page sizes, index stride, cache record layouts, and resident RAM budgets still need final code-level numbers.
- Simulator and firmware `NavigationCacheFS` backends must normalize paths identically.
- Source mtime reliability on F435 may be limited; source CRC fallback must be tested for large files without blocking.
- Full CRC validation and first acquisition must be carefully staged to avoid UI stalls on very large routes.
- Cue candidate derivation thresholds need tuning with real GPX files, especially dense switchbacks and noisy tracks.
- StorageService temp-write/replace may require platform-specific support if LVGL FS remains insufficient for general JSON saves.
- Long-route import test data is needed to validate RAM, timing, and warning behavior.

## Out Of Scope
- Automatic reverse-route navigation.
- Street-name turn-by-turn navigation.
- Online route planning or rerouting.
- BLE/phone GPX import flow.
- Recursive full-SD GPX scanning.
- Clearing/deleting route caches from UI.
- Voice prompts.
- Heavy custom LVGL drawing, masks, shadows, or animation-heavy route effects.
