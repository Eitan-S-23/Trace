# Plan: Dialplate HUD Watchface System v1
_Locked via grill by Codex + user_

## Goal
Redesign the bike-computer `Dialplate` dashboard for a 240x320 portrait screen so it closely replicates `generated-images/2.png`, while upgrading the page into watchface system v1. The default built-in watchface must preserve the reference design's structure and visual hierarchy: top status/navigation, left status/speed/chart, central cyber-map route, right altitude/grade/AVG/TIME/TRIP/CAL metric stack, and bottom MAP/REC/MENU actions. The system must also prepare for a separate phone/upper-computer app to install, list, activate, and switch multiple downloadable watchfaces over BLE using safe declarative packages stored on SD card.

## Approach
1. Preserve the grilled decisions and external app handoff:
   - Keep `DIALPLATE_GRILL_NOTES.md` as the decision log.
   - Keep `WATCHFACE_APP_AGENT_SPEC.md` as the phone-app agent contract.
   - Update both if implementation details change.
2. Set the simulator target to 240x320 portrait:
   - Change `LinuxSDL2/Makefile` from `-DLV_HOR_RES=480 -DLV_VER_RES=320` to `-DLV_HOR_RES=240 -DLV_VER_RES=320`.
   - Avoid touching hardware screen constants because `USER/HAL/HAL_Config.h` already uses 240x320.
3. Add a compact watchface domain under `USER/App/Utils/Watchface`:
   - Define package/constants: `/Watchfaces`, `/Watchfaces/.install`, built-in ID, ID/path limits, widget limits.
   - Define a `WatchfaceData` snapshot with whitelisted data sources: speed, avgSpeed, maxSpeed, tripDistance, elapsedTime, calorie, altitude, gpsSatellites, gpsCourse, battery, recState, BLE/status placeholders, and navigation placeholders.
   - Define a `WatchfaceManifest` / `WatchfaceWidget` model for v1 built-in/declarative rendering.
   - Implement a small manager that can return the built-in manifest, scan SD package manifests later, track active ID, and fall back to built-in on SD/malformed package failures.
4. Implement the built-in HUD watchface as firmware data and LVGL primitives:
   - Use no SD assets for the default face.
   - Draw a dark cyber background, subtle map grid/road lines, cyan cut-corner panel frames, neon-green route preview, rotated current-position arrow, top navigation banner, left speed block and mini chart, right metric stack, and bottom MAP/REC/MENU bar.
   - Keep all major reference modules; only compress tiny details for 240x320: smaller labels, fewer decorative ticks, abbreviated text, simplified mini chart, and tighter spacing.
5. Refactor `DialplateView` around the watchface renderer:
   - Replace the current hard-coded gray top panel/four-text layout with a renderer-owned UI tree.
   - Keep direct handles for action buttons and frequently updated labels/route arrow so updates do not recreate the whole tree every second.
   - Use existing fonts from `ResourcePool` only.
   - Use LVGL line/label/container primitives and optional `lv_img` only for built-in compiled icons already in `ResourcePool`.
6. Extend `DialplateModel` data collection:
   - Subscribe/pull `SportStatus`, `GPS`, and `Power` where available.
   - Keep existing `Recorder`, `StatusBar`, `MusicPlayer` integration.
   - Provide `gpsCourse` to rotate the HUD direction arrow.
   - Use real data when available; use configurable placeholders for navigation instruction/distance/street, heart rate, grade, waypoint labels, and any missing design-reference data.
7. Preserve and adjust bottom actions:
   - `MAP` opens `Pages/LiveMap`.
   - `REC` preserves current record state behavior: long press starts/stages stop/stops, short press pauses/continues.
   - `MENU` opens `Pages/MainMenu` instead of `Pages/SystemInfos`.
8. Add persistent settings for active watchface:
   - Extend `SysConfig_Info_t` with `watchfaceId[32]` or equivalent compact field.
   - Register it with `Storage` so `/SystemSave.json` persists it.
   - Use built-in ID as the default and fallback.
9. Add a minimal controlled SD helper for watchface installation:
   - Reuse the global `SdFatSdioEX SD` from `HAL_SD_CARD.cpp` through a declared helper interface rather than broad direct access from UI code.
   - Support ensure-directory, file open/write/truncate, remove temp install leftovers where practical, and manifest file existence checks.
   - Keep file operations out of LVGL rendering paths except image/path reading.
10. Extend BLE command handling in `Libraries/Bluetooth` / `USER/HAL/HAL_Bluetooth.cpp`:
   - Keep existing `+...\r\n` framing and 256-byte receive buffer constraints.
   - Add `WF_BEGIN`, `WF_CHUNK`, `WF_END`, `WF_LIST?`, `WF_ACTIVE?`, and `WF_ACTIVATE:<id>`.
   - Use HEX chunk payloads.
   - Write install data to `/Watchfaces/.install/<id>/`.
   - Validate manifest presence, schema, target 240x320, safe ID/path rules, and chunk CRC at minimum.
   - Return compact responses such as `+WF_OK:<command>\r\n`, `+WF_ERR:<code>,<message>\r\n`, `+WF_LIST:[...]\r\n`, and `+WF_ACTIVE:<id>\r\n`.
11. Keep v1 boundaries explicit:
   - No arbitrary scripts or native code upload.
   - No dynamic third-party font loading.
   - No compressed archive extraction.
   - No required resume-after-disconnect.
   - No phone-side package builder in this repo.
12. Verify:
   - Build or at least compile-check via available LinuxSDL2 tooling if the local environment supports it.
   - If the simulator cannot build in the current environment, run targeted static checks and report the limitation.
   - Review compile risk around C++ allocation, LVGL object lifetime, SD file operations, and packet size handling.

## Key Decisions & Tradeoffs
- Target layout is 240x320 portrait for both hardware and simulator. This matches the hardware and the reference image orientation; it may require small simulator Makefile changes.
- The default dashboard must replicate `generated-images/2.png` structurally. Major modules must not be removed; only fine detail can be simplified for small-screen readability.
- The central map/route on the default watchface is a lightweight HUD route preview, not embedded `LiveMap` tile rendering. This avoids heavy tile decode/refresh on the dashboard while keeping the full map page behind the MAP action.
- The route arrow uses real `GPS_Info.course` so it points in the current travel direction.
- Missing data sources are placeholders, not fake firmware sensors. Navigation text, heart rate, grade, and waypoint labels stay configurable for future phone/navigation integration.
- Watchface updates use safe declarative packages, not remote scripts/native code. This allows visually different faces while keeping the MCU renderer bounded.
- Downloaded packages live on SD under `/Watchfaces/<id>/`; firmware keeps a built-in HUD fallback for no-SD/corrupt-package cases.
- BLE v1 uses text commands and HEX chunks instead of binary framing. It is slower but simpler and compatible with the existing `+...\r\n` parser.
- BLE install v1 implements the minimum usable loop and omits resume, compression, and package garbage collection to keep scope manageable.
- MENU should route to `Pages/MainMenu`, not `Pages/SystemInfos`, because the UI label says MENU.

## Risks / Open Questions
- The current LVGL FS layer lacks mkdir/remove/rename APIs. A watchface SD helper must be added carefully without leaking broad filesystem manipulation into UI code.
- The existing BLE receive buffer is 256 bytes, so app chunks must stay small. If throughput is poor, a future binary protocol or larger buffer may be needed.
- The exact package-level CRC definition is not fully finalized. v1 can validate per-chunk CRC and manifest structure first, then align package CRC with the phone app spec before app integration.
- `Power` and BLE status data availability should be confirmed during implementation; unavailable fields should degrade to placeholders.
- Downloaded PNG backgrounds may be slow if redrawn frequently. The renderer should avoid unnecessary invalidation and prefer static backgrounds.
- Adding `watchfaceId` to `SysConfig_Info_t` affects persisted JSON. Defaults and missing-key handling must avoid breaking existing `/SystemSave.json` files.
- Existing worktree is dirty with user changes. Implementation must not revert unrelated changes.

## Out of scope
- Phone/upper-computer app implementation.
- Arbitrary script execution or native code watchfaces.
- Dynamic third-party font upload/loading.
- Full Garmin/Zepp-style app sandbox.
- BLE resume-after-disconnect.
- Compressed watchface archives.
- Advanced animation engine beyond lightweight LVGL transitions or simple route/button glow.
- Deleting/garbage-collecting old watchface assets unless it is trivial and safe.
