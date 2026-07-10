# Watchface App Agent Spec

This file is for the AI agent working in the separate phone/upper-computer app project.
It describes the firmware-side watchface package and BLE protocol expected by this repository.

Status: draft v1, locked by grill decisions Q3-Q9.

## Target Device

- Device: AT32F435 + LVGL bike computer firmware.
- Display: 240x320 portrait.
- Runtime page: `Dialplate` will become a watchface renderer.
- Storage for downloaded watchfaces: SD card under `/Watchfaces/<id>/`.
- Built-in fallback watchface: firmware contains a default HUD face that does not require SD assets.
- Persistent active face state: firmware stores only lightweight settings such as active watchface ID in `/SystemSave.json`.

## App Responsibilities

- Build watchface packages containing `manifest.json` and optional PNG/bin assets.
- Transfer packages over BLE using the v1 text command protocol.
- List installed watchfaces.
- Query and set the active watchface.
- Avoid sending arbitrary scripts or native code. Firmware v1 only accepts declarative manifests and asset files.

## Watchface Package Layout

Each downloadable face is a directory:

```text
/Watchfaces/<id>/
  manifest.json
  assets/
    background.png
    icon_map.png
    icon_menu.png
```

During installation, firmware writes to a temporary directory first:

```text
/Watchfaces/.install/<id>/
```

Only after all files and checksums pass validation should firmware commit/register it as:

```text
/Watchfaces/<id>/
```

## Manifest Schema

Required fields:

```json
{
  "schema": 1,
  "id": "hud_neon_v1",
  "name": "Neon HUD",
  "version": 1,
  "target": {
    "width": 240,
    "height": 320
  },
  "assets": [
    {
      "id": "bg",
      "type": "png",
      "path": "assets/background.png",
      "crc32": "00000000",
      "size": 0
    }
  ],
  "widgets": [],
  "packageCrc32": "00000000"
}
```

Recommended optional fields:

```json
{
  "author": "phone-app",
  "description": "Cyber HUD style watchface",
  "createdAt": "2026-06-14",
  "accentColor": "#8CFF2E"
}
```

Validation rules:

- `schema` must be `1`.
- `target.width` must be `240`.
- `target.height` must be `320`.
- `id` should use ASCII lowercase letters, digits, `_`, or `-`.
- Asset paths must be relative paths inside the watchface directory.
- Widgets must use firmware-whitelisted types only.
- CRC32 values are hex strings, uppercase or lowercase accepted.

## Widget Model

Firmware v1 supports these declarative widget types:

- `image` or `background`
- `label`
- `metric`
- `panel`
- `line`
- `polyline`
- `routePreview`
- `statusIcon`
- `button`

Common widget fields:

```json
{
  "id": "speed",
  "type": "metric",
  "x": 16,
  "y": 118,
  "w": 110,
  "h": 70,
  "z": 20,
  "visible": true
}
```

Common visual fields:

```json
{
  "color": "#EAFBFF",
  "accentColor": "#18D8FF",
  "bgColor": "#04121A",
  "opacity": 220,
  "font": "bahnschrift_65",
  "align": "left"
}
```

Supported firmware fonts are expected to include:

- `bahnschrift_13`
- `bahnschrift_17`
- `bahnschrift_24`
- `bahnschrift_32`
- `bahnschrift_65`
- `agencyb_36`

Do not rely on dynamic third-party font upload in v1.

## Data Sources

The app should only bind widgets to these data source names:

- `speed`
- `avgSpeed`
- `maxSpeed`
- `tripDistance`
- `elapsedTime`
- `calorie`
- `gpsSatellites`
- `gpsCourse`
- `battery`
- `recState`

Metric widget example:

```json
{
  "id": "speed",
  "type": "metric",
  "x": 14,
  "y": 116,
  "w": 98,
  "h": 76,
  "data": "speed",
  "format": "%.1f",
  "unit": "KM/H",
  "font": "bahnschrift_65",
  "unitFont": "bahnschrift_17",
  "color": "#F2FBFF",
  "unitColor": "#18D8FF",
  "z": 30
}
```

## BLE Transport

Existing firmware framing is text based:

```text
+<payload>\r\n
```

Watchface v1 commands use the `WF_` prefix.

Payload must fit the firmware receive buffer. Current parser uses a 256-byte packet buffer, so the app should keep every full `+...\r\n` packet under 240 payload characters unless firmware later reports a larger MTU/buffer.

Binary file bytes must be HEX encoded in v1 to avoid control-character framing problems.

## BLE Commands

Begin an install session:

```text
+WF_BEGIN:<json>\r\n
```

Example:

```text
+WF_BEGIN:{"id":"hud_neon_v1","files":2,"total":18342}\r\n
```

Send a file chunk:

```text
+WF_CHUNK:<path>,<offset>,<chunkCrc32>,<hex>\r\n
```

Example:

```text
+WF_CHUNK:manifest.json,0,A1B2C3D4,7B22736368656D61223A317D\r\n
```

End and validate install:

```text
+WF_END:<packageCrc32>\r\n
```

List installed faces:

```text
+WF_LIST?\r\n
```

Query active face:

```text
+WF_ACTIVE?\r\n
```

Activate an installed face:

```text
+WF_ACTIVATE:<id>\r\n
```

Delete is planned but not required in the minimum v1 firmware loop unless explicitly implemented:

```text
+WF_DELETE:<id>\r\n
```

## Expected Responses

Firmware should respond with compact text lines over the same BLE serial channel.

Recommended response shapes for the app to expect:

```text
+WF_OK:<command>\r\n
+WF_ERR:<code>,<message>\r\n
+WF_LIST:[{"id":"builtin_hud","name":"Built-in HUD"},{"id":"hud_neon_v1","name":"Neon HUD"}]\r\n
+WF_ACTIVE:<id>\r\n
```

The app should treat any `WF_ERR` as a failed operation and keep the previous active face selected.

## Install Flow

1. Generate `manifest.json`.
2. Compute CRC32 for each asset file and write it into `manifest.json`.
3. Compute package CRC32 according to the firmware definition once finalized.
4. Send `WF_BEGIN`.
5. Send `manifest.json` in `WF_CHUNK` packets.
6. Send every asset file in `WF_CHUNK` packets.
7. Send `WF_END`.
8. Query `WF_LIST?`.
9. Send `WF_ACTIVATE:<id>` if the user chooses to activate the new face.
10. Query `WF_ACTIVE?` and update app UI.

## V1 Scope Boundaries

- No arbitrary scripts.
- No native code upload.
- No complex animation engine.
- No dynamic third-party font loading.
- No compressed archive extraction in firmware.
- No required resume-after-disconnect support in v1.
- No phone-side package builder exists in this firmware repo; the phone app project should implement it.

## Default Built-In HUD Face

The firmware built-in face will visually match the reference design:

- Dark cyber HUD background.
- Cyan cut-corner panels.
- Neon-green route preview.
- Direction arrow rotated by current GPS course.
- Large speed readout.
- Secondary ride metrics.
- Bottom `MAP`, `REC`, `MENU` actions.

The exact `240x320` information density is still being grilled in the firmware project.
