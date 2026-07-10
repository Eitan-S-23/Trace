# Navigation GPX Plan Draft
_Live draft for grill-me discussion. Not locked._

## Current Code Facts
- Map UI is implemented by `USER/App/Pages/LiveMap/LiveMap.cpp`, `LiveMapView.cpp`, `LiveMapModel.cpp`.
- `LiveMap` renders SD-card map tiles through `MapConv` + `TileConv`, keeps a GPS arrow on the map, and overlays current sport speed/trip/time.
- The existing orange polyline is the active recorded track. It is sourced from `DataProc::TrackFilter`, not from an imported route file.
- `GPX_Parser` exists and can stream `<trkpt lat="..." lon="...">`, `<ele>`, and `<time>` from a `Stream` callback, but it does not parse `<rtept>` and has no route state API.
- `MainMenu` has a navigation settings page, but the rows are static placeholders. It does not select or load GPX files.
- `FileBrowser` exists as standalone LVGL code and handles image/bin/mp4 extensions, but it is not integrated as a `PageBase` page and does not handle `.gpx`.

## Initial Recommendation
Implement navigation in two layers:

1. Add a route data/model layer that loads a GPX route from SD card, converts WGS84 coordinates to map coordinates, filters/simplifies points, and exposes route status.
2. Extend `LiveMap` to draw the imported route as a separate polyline, calculate nearest route progress from current GPS, and show lightweight guidance information.

## Draft Scope
- MVP should import one GPX file from SD card and render it as a planned route on `LiveMap`.
- MVP should support following progress and off-route detection.
- MVP should avoid turn-by-turn street navigation unless GPX contains route cues or we define simple geometry-derived turn prompts.
- MVP should reuse existing `TrackPointFilter`, `TrackLineFilter`, `MapConv`, `TileConv`, and `lv_poly_line` where possible.

## Key Risks
- RAM is limited. Loading all GPX points into RAM may fail for long routes, so route simplification or a compact point container is required.
- `lv_poly_line` stores points in `std::vector`, so drawing a very dense GPX directly can fragment memory and degrade rendering.
- `GPX_Parser` currently only finds `<trkpt>`, while many navigation GPX files use `<rtept>`.
- USB MSC access blocks `LiveMap` because both need SD card access.
- Existing `LiveMap` performance is sensitive to full-screen redraws; route drawing must be clipped to visible tile area and updated only when tiles/zoom change.

## Grill Questions
### Q1: What should "imported GPX navigation route" mean for the first implementation?
Recommended answer: fixed SD-card route file under `/Navigation/current.gpx`, loaded automatically by `LiveMap`, with file-selection UI deferred.

Alternative A: choose `.gpx` from an integrated file browser in `MainMenu > 导航设置`.

Alternative B: import GPX over BLE/phone app later; firmware only consumes an already-installed route file.

Decision: Alternative A. The first implementation must let the user choose a `.gpx` file from the menu.

Implementation consequence:
- Add a PageManager-integrated GPX route selection UI instead of relying on the current standalone `FileBrowser`.
- `PageManager::Push/Replace` supports `PageBase::Stash_t`, so the selected path can be passed to `LiveMap` when starting navigation.
- `PageManager::Pop()` has no return-value stash, so returning a selected path back to `MainMenu` is not the cleanest path unless route state is stored in a DataProc/global navigation model.

### Q2: After selecting a GPX in the menu, what should happen immediately?
Recommended answer: selecting a GPX starts navigation and opens `LiveMap` immediately, passing the selected file path as stash.

Alternative A: selecting a GPX only marks it as the active route and returns to the navigation settings page; the user enters `LiveMap` separately.

Alternative B: selecting a GPX opens a route preview/details page first, then user confirms start.

Decision: Alternative A. Selecting a GPX marks it as the active route and returns to the navigation settings page. The user enters `LiveMap` separately.

Implementation consequence:
- The selected route path needs to be stored somewhere outside the file picker page.
- Passing the path directly to `LiveMap` via stash is insufficient for this workflow because `LiveMap` is not opened immediately.
- A navigation route state holder is required, likely a new `DataProc::Navigation` node or an extension to persistent `SysConfig`.

### Q3: Should the selected GPX route persist after reboot?
Recommended answer: yes. Store the active route path in `SysConfig`/storage so the chosen route remains selected after power cycle, while route geometry is parsed lazily when `LiveMap` opens.

Alternative A: no persistence. Store only in RAM and clear it after reboot.

Alternative B: persist both the active route path and a compact preprocessed route cache file for faster loading.

Decision: Recommended. Persist the selected GPX route path, but parse route geometry lazily when `LiveMap` opens.

Implementation consequence:
- Extend persistent configuration or add a navigation-specific persistent key for the selected GPX path.
- Do not load or keep route geometry in `MainMenu`; menu should only browse and store the selected path.
- `LiveMap` should detect the active route path on appear, load/simplify it, and render it if valid.

### Q4: What navigation guidance is in scope for the first implementation?
Recommended answer: route rendering, nearest-route progress, remaining distance, and off-route warning. No true turn-by-turn street instructions yet.

Alternative A: add geometry-derived turn hints such as left/right/straight based on upcoming route bearing changes.

Alternative B: require GPX route cue metadata and display those cues if present.

Alternative C: only draw the route on the map, no progress/off-route/remaining distance.

Decision: Alternative A. First implementation should include geometry-derived turn hints such as left/right/straight based on upcoming route bearing changes.

Implementation consequence:
- The route model needs nearest-route progress, cumulative distance, and an upcoming-turn detector.
- Turn hints should be explicitly labeled as geometry-derived, not street-name navigation.
- Recommended first-pass thresholds: look ahead 30-120 m, compare incoming/outgoing segment bearings, classify large heading deltas as left/right/sharp left/sharp right/U-turn/straight.
- Turn hint calculations should run at a low rate, e.g. once per GPS update or once per second, not every LVGL frame.

### Q5: Which GPX point types must be accepted?
Recommended answer: support both `<trkpt>` and `<rtept>` in the firmware parser. Many exported navigation files use tracks, while route-planning tools may export route points.

Alternative A: support only `<trkpt>` for first version, matching the existing parser.

Alternative B: support `<trkpt>`, `<rtept>`, and `<wpt>`, treating waypoints as optional markers instead of route geometry.

Decision: Alternative B. Support `<trkpt>`, `<rtept>`, and `<wpt>`, with `<wpt>` treated as optional waypoint markers instead of route geometry.

Implementation consequence:
- Extend or replace `GPX_Parser` so it can identify point type and parse coordinate attributes for all three tags.
- Route geometry should use `<trkpt>` if present; otherwise use `<rtept>`. `<wpt>` should not connect into the route line.
- Waypoints need a bounded storage/display policy to avoid unbounded RAM usage.
- Waypoints can be shown as small labels/pins on `LiveMap` if inside the visible tile area.

### Q6: How should long GPX routes be handled on this device?
Recommended answer: parse the selected GPX once when opening `LiveMap`, simplify route points into a compact in-RAM container with a hard point cap, and reject/trim routes that exceed the cap with a visible status message.

Alternative A: stream GPX from SD every time the map tile area changes, avoiding full route RAM but increasing SD reads and complexity.

Alternative B: after file selection, preprocess GPX into a compact binary cache on SD, then `LiveMap` loads the cache.

Alternative C: load full GPX into RAM/vector without a hard cap.

Decision: Alternative B. After file selection, preprocess the GPX into a compact binary cache on SD. `LiveMap` loads the cache instead of reparsing XML.

Implementation consequence:
- Add an import/preprocess step in the GPX selection flow.
- Store the selected source GPX path and the generated cache path persistently.
- Cache must contain simplified route geometry, cumulative distances or enough data to compute remaining distance efficiently, derived turn points, and bounded waypoint markers.
- `LiveMap` should fail gracefully if the cache is missing/stale and offer a clear status instead of blocking on XML parsing.
- Cache format needs a version/magic/checksum or source timestamp/size metadata so incompatible or stale caches are detected.

### Q7: Where should route cache files live, and how should stale caches be handled?
Recommended answer: create `/Navigation/Cache/` and derive a deterministic cache filename from the source GPX filename plus file size/mtime if available. If source GPX changes, rebuild cache when the user selects it again.

Alternative A: write one fixed cache file `/Navigation/current.nav`, overwritten every time a route is selected.

Alternative B: write the cache next to the GPX file using the same basename plus `.nav`.

Alternative C: keep multiple caches in `/Navigation/Cache/` and rebuild automatically in `LiveMap` if stale.

Decision: Recommended. Cache files live under `/Navigation/Cache/`; cache names are derived from the source GPX filename and file metadata. Source changes are handled by rebuilding cache when the user selects the GPX again.

Implementation consequence:
- GPX selector should ensure `/Navigation/Cache/` exists before preprocessing.
- Cache header should store source path, source size, source date/time if available, route point count, waypoint count, turn count, total distance, format version, and checksum.
- Persistent navigation state should store both source GPX path and cache path.
- `LiveMap` should trust only a cache whose header version and source metadata match the persisted state.

### Q8: What should the user see while a GPX is being imported/preprocessed?
Recommended answer: show a modal/progress page from the selector: "Importing route...", then success/failure summary. On success return to navigation settings with route name displayed.

Alternative A: block briefly with a simple spinner/no percentage, then return.

Alternative B: do preprocessing in the background and let user continue using menus.

Alternative C: perform import silently and only show errors.

Decision: Recommended. Show Chinese import progress/result UI. It is acceptable to generate/update a Chinese subset font with the font generation tool.

Implementation consequence:
- Use Chinese labels for import status and errors, e.g. "正在导入路线", "导入成功", "导入失败", "路线点过少", "文件无法打开", "路线已选择".
- Use existing `ResourcePool::GetFont("cn_16")` when possible.
- If required characters are missing, update `Tools/font_gen/font_config.json` and regenerate `USER/App/Resource/Font/font_cn_16.c` with `Tools/font_gen/gen_font.py` or `gen_font.bat`.
- Because the firmware uses ARMCC 5, write Chinese source strings as UTF-8 `\xNN` escaped C string literals generated by `python Tools/font_gen/gen_font.py --cstr "<中文>"`.
- If a new font file is added instead of updating `font_cn_16.c`, also register it in `ResourcePool.cpp`, add it to the simulator project, add it to the Keil project, and include it in the F435 build/link flow.

### Q9: Where should navigation guidance appear on `LiveMap`?
Recommended answer: add a compact top guidance banner on `LiveMap` showing next-turn icon/text and distance, plus a small bottom/right status line for remaining distance and off-route warning. Keep map tiles visible and avoid heavy shadows/transparency.

Alternative A: reuse/expand the existing bottom-left sport info panel, showing speed plus navigation values.

Alternative B: add a full-width bottom navigation panel.

Alternative C: keep all guidance only on the Dialplate dashboard; `LiveMap` only draws route and waypoints.

Decision: Keep the current bottom-left sport info panel unchanged/reused. Add a compact transparent top navigation banner showing next-turn icon, turn text, and distance.

Implementation consequence:
- Do not replace the current bottom-left `sportInfo` panel.
- Add a top overlay group in `LiveMapView` for navigation guidance.
- The banner should be transparent per user requirement. To reduce LiveMap redraw cost, avoid `shadow_*`, masks, custom draw events, gradients, and large semi-transparent rectangles.
- Prefer labels/images directly over the map, with only content/position updates when the navigation state changes.
- If readability is poor on bright tiles, use text color/outline-like duplicate labels sparingly instead of a heavy translucent panel.

### Q10: What exactly should "transparent banner" mean visually?
Recommended answer: fully transparent container, no background rectangle; only icon/text/distance labels are visible.

Alternative A: semi-transparent dark background, e.g. 40-60% black, still called transparent by users but costs more redraw.

Alternative B: transparent container plus a very small solid backing only behind text, no full-width panel.

Decision: Use an effect similar to the current bottom-left sport info panel: semi-transparent dark rounded background behind the compact top banner.

Implementation consequence:
- Use a small semi-transparent dark banner with rounded corners, visually consistent with `LiveMapView::SportInfo_Create`.
- Do not add new shadow styles even if the current shared `styleCont` has `shadow_width=10`; project guidance and prior LiveMap profiling show shadows are expensive on moving map tiles.
- Consider splitting navigation banner style from the current shared `styleCont` so the top banner can keep the desired translucent look without inheriting costly shadow.
- Keep banner dimensions compact and update labels only when values change.

### Q11: Should navigation also update the Dialplate/dashboard top navigation area?
Recommended answer: yes, expose navigation status through a `DataProc::Navigation` snapshot so Dialplate can later show the same next-turn/distance data, but first implementation only guarantees `LiveMap` UI.

Alternative A: implement both `LiveMap` and Dialplate navigation display in the first pass.

Alternative B: keep navigation status private to `LiveMap` only.

Decision: Alternative A. First implementation updates both `LiveMap` and Dialplate navigation display.

Implementation consequence:
- Add a shared `DataProc::Navigation` snapshot instead of computing navigation only inside `LiveMap`.
- `LiveMap` and `Dialplate` should both subscribe/pull navigation state.
- Dialplate already has nav UI handles: `ui.nav.labelDist`, `labelDistUnit`, `labelTurnIcon`, `labelTurnText`, and `DialplateView::SetTurnDirection()`.
- Replace Dialplate's current course-difference placeholder turn logic with route-derived navigation state when an active route is available.
- Keep a fallback placeholder/straight state when no route is selected or navigation cache is invalid.

### Q12: Which route import/selection UI should be implemented?
Recommended answer: create a new PageManager page, e.g. `Pages/RouteSelect`, with a focused list rooted at `0:/` or `/Navigation`, filtering `.gpx` files and directories. Reuse ideas from `FileBrowser` but do not use the current standalone `FileBrowser` directly.

Alternative A: retrofit the existing standalone `FileBrowser` into a PageBase page and add `.gpx` handling.

Alternative B: add a route list inside `MainMenu` itself, without a separate page.

Decision: Recommended. Create a new PageManager-integrated route selection page. The old `FileBrowser` is an early demo and must not be trusted as production code without detailed review; rewrite the selector if that is cleaner.

Implementation consequence:
- Add a new page such as `USER/App/Pages/RouteSelect/RouteSelect.{h,cpp}` and register it in `AppFactory` and `App.cpp`.
- Use `FileBrowser` only as a reference for FatFs directory traversal and LVGL list patterns, not as a direct dependency.
- Route selector should be encoder/key friendly, match the current `MainMenu` focus behavior, and filter to directories plus `.gpx` files.
- Implement deterministic memory ownership for path strings; avoid raw `malloc/free` event-user-data patterns from the old demo.
- Add clear handling for SD missing, directory open failure, empty directory, invalid GPX, import failure, and user back.

### Q13: What directory should the route selector start in and allow browsing?
Recommended answer: start in `0:/Navigation` if it exists, otherwise create it or show an empty-state prompt. Allow going up to `0:/` so the user can pick GPX files elsewhere on the SD card.

Alternative A: restrict browsing to `0:/Navigation` only.

Alternative B: start at `0:/` and allow browsing the whole SD card.

Alternative C: scan the whole SD card recursively for `.gpx` and show a flat list.

Decision: Recommended. Start in `0:/Navigation` and allow browsing up to `0:/`.

Implementation consequence:
- On route selector load, try to open/create `0:/Navigation`.
- If creation/open fails, show a Chinese error and fall back to `0:/` if possible.
- Directory traversal must clamp at `0:/`; no path should escape the SD volume.
- Selector lists directories plus `.gpx` files only.

### Q14: How should off-route detection work?
Recommended answer: warn when current GPS is more than 40 m from the nearest route segment for at least 2 consecutive GPS updates; clear warning after returning within 25 m.

Alternative A: stricter cycling mode, e.g. warn above 25 m and clear below 15 m.

Alternative B: looser outdoor mode, e.g. warn above 80 m and clear below 50 m.

Alternative C: no off-route warning in first version.

Decision: Recommended, with an explicit initial approach state because users may start navigation far away from the route.

Implementation consequence:
- Use 40 m off-route threshold with 2 consecutive GPS updates, and clear below 25 m.
- Add route-following states: no route, loading/importing, approaching route, on route, off route, finished, error.
- When navigation starts and the user is far from the route, show "前往路线" / distance-to-route instead of immediately treating it as a repeated off-route error.
- Once the user first enters the route corridor, switch to normal on-route/off-route behavior.
- If the nearest route point is near the end while the user has not started, avoid marking route as finished prematurely.

### Q15: What should happen when the user starts far from the route?
Recommended answer: enter an "approaching route" mode that shows distance to the nearest route point/segment and a simple bearing/straight-line direction to the route. Do not calculate remaining route distance until the user enters the corridor.

Alternative A: immediately snap progress to the nearest route point and start normal navigation even if far away.

Alternative B: ask user to confirm starting from nearest point if farther than a threshold.

Alternative C: refuse to start navigation until within route corridor.

Decision: Recommended. Use "approaching route" mode when the user starts far from the route.

Implementation consequence:
- Guidance text should show "前往路线" and distance to nearest route segment/point.
- If possible, show a simple direction arrow based on bearing from current GPS to the nearest route point/segment projection.
- Do not show normal remaining-route distance or upcoming-turn instructions until entering the route corridor.
- Once within the on-route corridor, initialize progress from the matched segment and transition to normal navigation.

### Q16: Should reverse-direction navigation be supported?
Recommended answer: first version follows GPX point order only. If the user enters the route near the end or moves opposite the route direction, show "路线方向相反" / off-route-like warning rather than automatically reversing.

Alternative A: auto-detect reverse travel and reverse route progress/navigation.

Alternative B: offer a menu toggle to navigate the selected GPX forward or reverse.

Alternative C: ignore direction entirely and always snap to nearest point.

Decision: Recommended. First version follows GPX point order only and does not automatically reverse the route.

Implementation consequence:
- Route cache stores geometry in source GPX order.
- Progress matching should enforce mostly monotonic forward progress after the route is acquired.
- If user movement/course indicates persistent reverse travel after route acquisition, show "路线方向相反" or equivalent warning.
- Do not silently reverse remaining distance or turn hints in the first version.

### Q17: When should navigation be considered finished?
Recommended answer: mark finished when progress reaches the final route segment and current GPS is within 30 m of the route end for at least 2 GPS updates. Keep showing finished until a new route is selected or navigation is stopped.

Alternative A: finish when remaining route distance is below 50 m, regardless of endpoint distance.

Alternative B: finish only when within 15 m of the route end.

Alternative C: never auto-finish; user manually stops/clears route.

Decision: Recommended. Finish when the user is on the final route segment and within 30 m of the route end for at least 2 GPS updates.

Implementation consequence:
- Add a `finished` navigation state that persists until user selects a new route or clears/stops navigation.
- Do not clear selected route automatically on finish.
- Finished state should display a Chinese completion message on `LiveMap` and a neutral/complete state on Dialplate.
- Use hysteresis/counter logic to avoid finish-state flicker near the endpoint.

### Q18: How should the user stop or clear the active route?
Recommended answer: add navigation settings rows for "选择路线", "停止导航", and current route name/status. "停止导航" clears active navigation state but keeps the selected route path/cache available for later; a separate "清除路线" can be added later if needed.

Alternative A: "停止导航" clears both active navigation and selected route/cache path.

Alternative B: no explicit stop; selecting another route replaces current route.

Alternative C: add both "停止导航" and "清除路线" in first version.

Decision: Recommended. Add navigation settings rows for selecting a route, stopping navigation, and showing current route/status. Stopping navigation does not clear the selected route/cache path.

Implementation consequence:
- Navigation settings should show active route name/status.
- "选择路线" opens the new `RouteSelect` page.
- "停止导航" switches navigation state to stopped/inactive but keeps persisted selected GPX/cache paths.
- A later implementation can add explicit "清除路线" if needed.

### Q19: After a route is selected/imported, should navigation be active automatically?
Recommended answer: yes. Selecting/importing a route makes it the selected route and enables navigation. If the user later chooses "停止导航", the route remains selected but inactive; add a "开始导航" row to restart the selected route.

Alternative A: selecting a route only stores it; user must choose "开始导航" separately.

Alternative B: selecting a route enables only route display, but guidance/off-route remains disabled until "开始导航".

Decision: Alternative A. Selecting/importing a route only stores it as the selected route. The user must choose "开始导航" separately to activate guidance.

Implementation consequence:
- Import success returns to navigation settings with the route name/status displayed, but navigation remains inactive.
- Add "开始导航" and "停止导航" actions to navigation settings. Their enabled/visible state depends on whether a valid selected route cache exists and whether navigation is active.
- `LiveMap` should be able to show "未开始导航" or selected-route preview state when a route is selected but inactive.

### Q20: When a route is selected but navigation is not started, should `LiveMap` still draw the route?
Recommended answer: yes. Draw the selected route as a preview on `LiveMap`, but do not show turn guidance, off-route warnings, route completion, or progress state until "开始导航" is selected.

Alternative A: do not draw the route until navigation is started.

Alternative B: draw the route and show remaining distance, but suppress warnings and turn prompts.

Decision: Recommended. `LiveMap` draws the selected route as a preview even when navigation is inactive.

Implementation consequence:
- Route rendering and route guidance are separate states.
- If selected route cache is valid, `LiveMap` loads and draws it regardless of active/inactive guidance state.
- Turn banner and Dialplate navigation values should show inactive/placeholder state until the user starts navigation.
- Off-route, approaching-route, reverse-direction, and finished logic only run when navigation is active.

### Q21: What RAM/rendering budget should the SD `.nav`/`.bin` route cache obey?
Note: this does not change Q6. The route is still preprocessed to an SD-card binary cache. This question is about how much of that cache the firmware may load/index/render at once, because `LiveMap` and `Dialplate` cannot safely allocate unbounded vectors.

Recommended answer: cap the preprocessed cache contents to 4096 simplified route points, 64 waypoints, and 256 derived turn cues. During preprocessing, simplify by map/distance tolerance and reject with a Chinese error if still over limit.

Alternative A: smaller cap: 2048 route points, 32 waypoints, 128 turns.

Alternative B: larger cap: 8192 route points, 128 waypoints, 512 turns.

Alternative C: no fixed cap; rely on available heap.

Decision: Recommended. The SD binary route cache has fixed route content budgets: 4096 simplified route points, 64 waypoint markers, and 256 derived turn cues.

Implementation consequence:
- The cache remains an SD-card binary file, but import/preprocess must enforce bounded content.
- `LiveMap` should not allocate unbounded route vectors from file contents.
- Import should simplify route geometry first; if output still exceeds limits, fail with a Chinese error rather than loading an unsafe route.
- The binary header must include counts, and loaders must validate counts before allocation/read.

### Q22: What extension/name should the route cache format use?
Recommended answer: use `.nav` under `/Navigation/Cache/` for route-navigation cache files to distinguish them from firmware/map `.bin` files already used in this project.

Alternative A: use `.bin` because the cache is binary.

Alternative B: use `.rte` or `.xnav`.

Decision: Recommended. Use `.nav` route cache files under `/Navigation/Cache/`.

Implementation consequence:
- Route cache files are binary but use `.nav` to avoid confusion with firmware `Track.bin` and map tile `.bin` files.
- Persistent navigation state stores source GPX path and generated `.nav` cache path.
- Route selector filters source files by `.gpx`, not `.nav`.

### Q23: Where should persistent navigation state be stored?
Observation: existing persistence is centralized through `StorageService` and `STORAGE_VALUE_REG(...)`, which writes registered DataProc fields to `SystemSave.json`. `SysConfig` already uses this, but route paths do not belong in the core system config struct.

Recommended answer: add a new `DataProc::Navigation` node with fixed-size fields for selected GPX path, selected `.nav` cache path, selected route name/status, and active flag. Register those fields with `Storage` so they persist in the existing `SystemSave.json`.

Alternative A: extend `SysConfig_Info_t` with selected route path/cache path and active flag.

Alternative B: add a separate navigation-specific JSON file such as `/Navigation/nav_state.json`.

Decision: Recommended. Add `DataProc::Navigation` and persist its fixed-size fields through the existing `StorageService/SystemSave.json` mechanism.

Implementation consequence:
- Add `Navigation_Info_t` and navigation commands to `DataProc_Def.h`.
- Add `DP_DEF(Navigation, sizeof(DataProc::Navigation_Info_t))` to `DP_LIST.inc`.
- Implement `DP_Navigation.cpp` with selected GPX path, selected `.nav` path, route display name, active flag, import/status fields, and current guidance snapshot.
- Register persistent fields with `STORAGE_VALUE_REG(...)` during `DATA_PROC_INIT_DEF(Navigation)`.
- Avoid unbounded path strings; use fixed-size char arrays.
- `RouteSelect`, `MainMenu`, `LiveMap`, and `Dialplate` communicate through this DataProc node.

### Q24: How should route import/preprocess run without freezing the UI?
Recommended answer: implement import as a cooperative stepper driven by an LVGL timer on the route import page. Each tick reads/parses a bounded chunk, updates Chinese progress text, and yields. Avoid long blocking loops in one event callback.

Alternative A: do the full import synchronously after file click and block UI until done.

Alternative B: create a FreeRTOS task for import/preprocess.

Decision: Recommended. Route import/preprocess runs as a cooperative LVGL timer stepper on the import page.

Implementation consequence:
- Do not parse the entire GPX in one click/event callback.
- Import page owns an LVGL timer that reads/parses bounded chunks per tick.
- Progress UI should remain responsive and show Chinese status.
- File I/O and LVGL updates stay on the UI thread, avoiding FreeRTOS/LVGL cross-thread hazards.
- User back/cancel should close the file and leave previous selected route state unchanged.

### Q25: What coordinate format should the `.nav` cache store?
Recommended answer: store WGS84 lat/lon as scaled integers plus cumulative distance. Convert to map pixel coordinates for the current zoom level when `LiveMap` loads/renders, because map zoom can change and cached map pixels at one level would become stale.

Alternative A: store map pixel coordinates only at the default map level for fastest rendering.

Alternative B: store both scaled WGS84 and default-level map pixels.

Decision: Recommended. Store WGS84 coordinates as scaled integers plus cumulative distance; convert to current map pixel coordinates when `LiveMap` renders.

Implementation consequence:
- `.nav` route points should use fixed-width scaled latitude/longitude, e.g. `int32_t latE7`, `int32_t lonE7`, plus cumulative distance in meters or centimeters.
- `LiveMap` converts route points through `MapConv` for the current zoom level.
- Zoom changes should invalidate/rebuild the route render polyline from cached route points, not require reimporting GPX.
- Turn detection can use WGS84/distance data from cache and does not depend on map zoom.

## Working Decisions
- GPX selection must be available from `MainMenu > 导航设置`.
- Selecting a GPX only sets the active route and returns to the navigation settings page; it does not immediately enter `LiveMap`.
- The selected GPX path persists after reboot. Route geometry is parsed lazily when `LiveMap` opens.
- First version includes geometry-derived turn hints in addition to route rendering, progress, remaining distance, and off-route warning.
- GPX parser must support `<trkpt>`, `<rtept>`, and `<wpt>`. Waypoints are markers, not connected route geometry.
- Selected GPX files are preprocessed into a compact SD-card route cache after selection. `LiveMap` consumes the cache, not raw XML.
- Route caches live in `/Navigation/Cache/` with deterministic names derived from source GPX metadata. Re-selecting a changed source rebuilds the cache.
- GPX import/preprocess UI uses Chinese status/error messages. Missing glyphs may be added with `Tools/font_gen`; AC5-safe escaped string literals are required in source.
- `LiveMap` keeps the existing bottom-left sport info panel and adds a compact transparent top guidance banner for next-turn icon/text/distance.
- The top guidance banner should visually match the current bottom-left semi-transparent dark rounded panel, but without adding new shadow rendering.
- First implementation must update both `LiveMap` and Dialplate navigation displays from shared route-derived navigation state.
- GPX selection uses a new `RouteSelect` PageManager page. The old standalone `FileBrowser` demo may be audited for ideas but should be rewritten if unsafe or overly buggy.
- Route selector starts in `0:/Navigation`, allows browsing up to `0:/`, and shows only directories plus `.gpx` files.
- Off-route detection uses 40 m enter / 25 m clear hysteresis, with an initial "approaching route" state for users who start far from the route.
- Far-from-route startup enters "前往路线" mode with distance/direction to the nearest route; normal remaining distance and turn hints begin after entering the route corridor.
- Reverse navigation is out of scope for first version. GPX point order defines route direction; reverse travel should be warned, not auto-corrected.
- Navigation auto-finishes near the route end: final segment plus 30 m endpoint distance for 2 GPS updates. Finished state remains until route is changed or stopped.
- Navigation settings include route selection, current route/status display, and stop navigation. Stopping does not erase the selected route/cache.
- Selecting/importing a GPX route does not start navigation automatically. User must choose "开始导航" separately.
- `LiveMap` previews a selected route even when navigation is inactive; guidance state begins only after "开始导航".
- SD binary route cache content is bounded: 4096 simplified route points, 64 waypoints, and 256 derived turn cues.
- Route cache files use `.nav` under `/Navigation/Cache/`.
- Persistent navigation route/status data lives in a new `DataProc::Navigation` node and is saved through existing `StorageService/SystemSave.json`.
- GPX import/preprocess is cooperative and timer-driven, not a single blocking event callback.
- `.nav` stores scaled WGS84 route geometry and cumulative distances; `LiveMap` converts to map pixels at the current zoom.
