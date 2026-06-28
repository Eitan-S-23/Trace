import { env } from "cloudflare:workers";
import { SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { editReleaseNotes, publishRelease } from "../src/admin_actions";
import { signDownloadToken } from "../src/downloads";
import { handleLatest } from "../src/latest";
import type { Platform, SecurityPayload, WorkerEnv } from "../src/types";

const APK_SHA = "a".repeat(64);
const OLD_SHA = "b".repeat(64);
const PATCH_SHA = "c".repeat(64);
const OUTPUT_SHA = "d".repeat(64);

describe("Phase 1 update-service invariants", () => {
  it("detects CAS conflict without writing channel_history", async () => {
    const appId = appIdFor("cas");
    const current = await seedRelease(appId, 100, "v1.0.0");
    const target = await seedRelease(appId, 101, "v1.0.1");
    const channelId = await seedChannel(appId, current.releaseId, 0);

    const conflict = await publishRelease(env, {
      appId,
      platform: "android",
      channel: "stable",
      releaseId: target.releaseId,
      expectedRevision: 1,
      rollback: false,
      actor: "tester@example.com",
      actorType: "test",
      requestId: `${appId}-conflict`
    });

    expect(conflict).toEqual({ ok: false, errorCode: "CAS_CONFLICT", status: 409 });
    expect(await historyCount(channelId)).toBe(0);

    const success = await publishRelease(env, {
      appId,
      platform: "android",
      channel: "stable",
      releaseId: target.releaseId,
      expectedRevision: 0,
      rollback: false,
      actor: "tester@example.com",
      actorType: "test",
      requestId: `${appId}-success`
    });

    expect(success).toEqual({ ok: true });
    expect(await historyCount(channelId)).toBe(1);
  });

  it("keeps disabled releases invisible and not downloadable", async () => {
    const appId = appIdFor("disabled");
    await seedApp(appId);
    const disabled = await seedRelease(appId, 200, "v2.0.0", { state: "disabled" });
    await seedChannel(appId, null, 0);

    const latest = await SELF.fetch(
      `http://example.com/api/public/latest?appId=${appId}&platform=android&channel=stable&versionCode=1&schemaVersion=2&capabilities=patch,full,payloadSignature`
    );
    const latestBody = await latest.json<{ errorCode: string; updateAvailable: boolean }>();
    expect(latest.status).toBe(200);
    expect(latestBody).toMatchObject({ errorCode: "NO_UPDATE", updateAvailable: false });

    const token = await tokenQuery(disabled.assetId, disabled.releaseId);
    const fallback = await SELF.fetch(`http://example.com/api/public/github-fallback?${token}`);
    const fallbackBody = await fallback.json<{ errorCode: string }>();
    expect(fallback.status).toBe(410);
    expect(fallbackBody.errorCode).toBe("ASSET_DISABLED");
  });

  it("gates GitHub fallback through D1 state and immutable tag URLs", async () => {
    const appId = appIdFor("fallback");
    const release = await seedRelease(appId, 300, "v3.0.0");
    await seedChannel(appId, release.releaseId, 0);
    const token = await tokenQuery(release.assetId, release.releaseId);

    const allowed = await SELF.fetch(`http://example.com/api/public/github-fallback?${token}`);
    expect(allowed.status).toBe(302);
    expect(allowed.headers.get("Location")).toContain("/releases/download/v3.0.0/");
    expect(allowed.headers.get("Location")).not.toContain("/latest/download/");

    await env.DB.prepare("UPDATE release_assets SET disabled = 1 WHERE id = ?")
      .bind(release.assetId)
      .run();
    const blocked = await SELF.fetch(`http://example.com/api/public/github-fallback?${token}`);
    const blockedBody = await blocked.json<{ errorCode: string }>();
    expect(blocked.status).toBe(410);
    expect(blockedBody.errorCode).toBe("ASSET_DISABLED");
  });

  it("rejects rollback to archived releases", async () => {
    const appId = appIdFor("archived");
    const current = await seedRelease(appId, 400, "v4.0.0");
    const archived = await seedRelease(appId, 399, "v3.9.9", { archived: 1 });
    await seedChannel(appId, current.releaseId, 0);

    const result = await publishRelease(env, {
      appId,
      platform: "android",
      channel: "stable",
      releaseId: archived.releaseId,
      expectedRevision: 0,
      rollback: true,
      actor: "tester@example.com",
      actorType: "test",
      requestId: `${appId}-rollback`
    });

    expect(result).toEqual({ ok: false, errorCode: "ASSET_ARCHIVED", status: 409 });
  });

  it("returns v1-compatible and v2 manifests from the same revision-keyed cache", async () => {
    const appId = appIdFor("compat");
    const release = await seedRelease(appId, 500, "v5.0.0");
    await seedPatch(appId, release.releaseId);
    await seedChannel(appId, release.releaseId, 7);

    const v1 = await SELF.fetch(
      `http://example.com/api/public/latest?appId=${appId}&platform=android&channel=stable&versionCode=1`
    );
    const v1Body = await v1.json<Record<string, unknown>>();
    expect(v1.status).toBe(200);
    expect(v1Body.schemaVersion).toBe(1);
    expect(v1Body.fullDownloadUrl).toContain("/api/public/download");
    expect(v1Body).not.toHaveProperty("payloadSignature");
    expect(v1Body).not.toHaveProperty("assets");

    const v2 = await SELF.fetch(
      `http://example.com/api/public/latest?appId=${appId}&platform=android&channel=stable&versionCode=1&schemaVersion=2&capabilities=patch,full,payloadSignature`
    );
    const v2Body = await v2.json<Record<string, unknown>>();
    expect(v2.status).toBe(200);
    expect(v2Body.schemaVersion).toBe(2);
    expect(v2Body.releaseId).toBe(release.releaseId);
    expect(v2Body.payloadSignature).toEqual({
      algorithm: "ed25519",
      keyVersion: "test",
      signature: "c2ln"
    });
    expect(v2Body.assets).toEqual([
      {
        assetType: "apk",
        fileName: "ble-monitor-android.apk",
        sha256: APK_SHA,
        size: 123456
      }
    ]);

    const cached = await env.MANIFEST_CACHE.get(
      `manifest:${appId}:android:stable:7`,
      "json"
    );
    expect(cached).toHaveProperty("v1");
    expect(cached).toHaveProperty("v2");
  });

  it("fails CI and download requests with invalid tokens", async () => {
    const ci = await SELF.fetch("http://example.com/api/ci/releases", {
      method: "POST",
      headers: {
        Authorization: "Bearer wrong",
        "Content-Type": "application/json"
      },
      body: JSON.stringify({})
    });
    const ciBody = await ci.json<{ errorCode: string }>();
    expect(ci.status).toBe(401);
    expect(ciBody.errorCode).toBe("TOKEN_INVALID");

    const download = await SELF.fetch(
      "http://example.com/api/public/download?assetId=a&releaseId=r&expiresAt=1&keyVersion=dev&signature=bad"
    );
    const downloadBody = await download.json<{ errorCode: string }>();
    expect(download.status).toBe(401);
    expect(downloadBody.errorCode).toBe("TOKEN_EXPIRED");
  });

  it("honors stop switches for latest and downloads", async () => {
    const appId = appIdFor("stops");
    const release = await seedRelease(appId, 600, "v6.0.0");
    await seedChannel(appId, release.releaseId, 0, { disableLatest: 1, disableDownloads: 1 });

    const latest = await SELF.fetch(
      `http://example.com/api/public/latest?appId=${appId}&platform=android&channel=stable&versionCode=1&schemaVersion=2&capabilities=patch,full,payloadSignature`
    );
    const latestBody = await latest.json<{ errorCode: string }>();
    expect(latest.status).toBe(200);
    expect(latestBody.errorCode).toBe("CHANNEL_STOPPED");

    const token = await tokenQuery(release.assetId, release.releaseId);
    const download = await SELF.fetch(`http://example.com/api/public/download?${token}`);
    const downloadBody = await download.json<{ errorCode: string }>();
    expect(download.status).toBe(503);
    expect(downloadBody.errorCode).toBe("CHANNEL_STOPPED");
  });

  it("fails closed when D1 is unavailable", async () => {
    const failingDb: D1Database = {
      prepare(): D1PreparedStatement {
        throw new Error("D1 failed");
      },
      dump(): Promise<ArrayBuffer> {
        throw new Error("not implemented");
      },
      batch<T = unknown>(): Promise<D1Result<T>[]> {
        throw new Error("not implemented");
      },
      exec(): Promise<D1ExecResult> {
        throw new Error("not implemented");
      },
      withSession(): D1DatabaseSession {
        throw new Error("not implemented");
      }
    };
    const fakeEnv: WorkerEnv = { ...env, DB: failingDb };

    const response = await handleLatest(
      new Request(
        "http://example.com/api/public/latest?appId=trace&platform=android&channel=stable&versionCode=1"
      ),
      fakeEnv,
      "d1-fail"
    );
    const body = await response.json<{ errorCode: string }>();
    expect(response.status).toBe(503);
    expect(body.errorCode).toBe("BACKEND_UNAVAILABLE");
  });

  it("allows releaseNotes edits without changing payload signature", async () => {
    const appId = appIdFor("notes");
    const release = await seedRelease(appId, 700, "v7.0.0", { releaseNotes: "Initial notes" });
    await seedChannel(appId, release.releaseId, 0);

    const before = await latestV2(appId);
    expect(before.releaseNotes).toBe("Initial notes");

    const result = await editReleaseNotes(env, {
      releaseId: release.releaseId,
      releaseNotes: "Edited notes",
      actor: "publisher@example.com",
      actorType: "test",
      requestId: `${appId}-edit-notes`
    });
    expect(result).toEqual({ ok: true });

    const after = await latestV2(appId);
    expect(after.releaseNotes).toBe("Edited notes");
    expect(after.payloadSignature).toEqual(before.payloadSignature);
    expect(after.assets).toEqual(before.assets);
  });
});

async function latestV2(appId: string): Promise<Record<string, unknown>> {
  const response = await SELF.fetch(
    `http://example.com/api/public/latest?appId=${appId}&platform=android&channel=stable&versionCode=1&schemaVersion=2&capabilities=patch,full,payloadSignature`
  );
  expect(response.status).toBe(200);
  return response.json<Record<string, unknown>>();
}

async function seedApp(appId: string): Promise<void> {
  await env.DB.batch([
    env.DB.prepare("INSERT OR IGNORE INTO apps (id, name) VALUES (?, ?)").bind(appId, appId),
    env.DB.prepare("INSERT OR IGNORE INTO app_config (app_id) VALUES (?)").bind(appId)
  ]);
}

async function seedRelease(
  appId: string,
  versionCode: number,
  releaseTag: string,
  options: {
    state?: "candidate" | "disabled";
    archived?: 0 | 1;
    releaseNotes?: string;
    platform?: Platform;
  } = {}
): Promise<{ releaseId: string; assetId: string }> {
  await seedApp(appId);
  const platform = options.platform ?? "android";
  const releaseId = `rel_${appId}_${platform}_${releaseTag.replaceAll(".", "_")}`;
  const assetId = `asset_${releaseId}_apk`;
  const payload: SecurityPayload = {
    appId,
    platform,
    versionName: releaseTag.slice(1),
    versionCode,
    releaseTag,
    apkAssetName: "ble-monitor-android.apk",
    apkSha256: APK_SHA,
    apkSize: 123456,
    patches: [],
    assetHashes: [
      {
        assetType: "apk",
        fileName: "ble-monitor-android.apk",
        sha256: APK_SHA,
        size: 123456
      }
    ],
    minClientVersionCode: 0,
    capabilities: ["patch", "full", "payloadSignature"]
  };

  await env.DB.batch([
    env.DB.prepare(
      `
        INSERT INTO releases (
          id,
          app_id,
          platform,
          version_name,
          version_code,
          release_tag,
          commit_sha,
          run_id,
          state,
          payload_signature_json,
          security_payload_json,
          release_notes,
          min_client_version_code,
          capabilities_json,
          archived
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
      `
    ).bind(
      releaseId,
      appId,
      platform,
      releaseTag.slice(1),
      versionCode,
      releaseTag,
      `${appId}-${versionCode}-commit`,
      `${appId}-${versionCode}-run`,
      options.state ?? "candidate",
      JSON.stringify({ algorithm: "ed25519", keyVersion: "test", signature: "c2ln" }),
      JSON.stringify(payload),
      options.releaseNotes ?? `Notes for ${releaseTag}`,
      JSON.stringify(payload.capabilities),
      options.archived ?? 0
    ),
    env.DB.prepare(
      `
        INSERT INTO release_assets (
          id,
          release_id,
          app_id,
          platform,
          asset_type,
          file_name,
          sha256,
          size_bytes,
          r2_state,
          github_url
        )
        VALUES (?, ?, ?, ?, 'apk', 'ble-monitor-android.apk', ?, 123456, ?, ?)
      `
    ).bind(
      assetId,
      releaseId,
      appId,
      platform,
      APK_SHA,
      options.archived === 1 ? "archived" : "not_uploaded",
      `https://github.com/Eitan-S-23/Trace/releases/download/${releaseTag}/ble-monitor-android.apk`
    )
  ]);

  return { releaseId, assetId };
}

async function seedPatch(appId: string, releaseId: string): Promise<void> {
  const assetId = `asset_${releaseId}_patch`;
  await env.DB.batch([
    env.DB.prepare(
      `
        INSERT INTO release_assets (
          id,
          release_id,
          app_id,
          platform,
          asset_type,
          file_name,
          sha256,
          size_bytes,
          r2_state,
          github_url
        )
        VALUES (?, ?, ?, 'android', 'patch', '100-to-500.tpatch', ?, 1000, 'not_uploaded', ?)
      `
    ).bind(
      assetId,
      releaseId,
      appId,
      PATCH_SHA,
      "https://github.com/Eitan-S-23/Trace/releases/download/v5.0.0/100-to-500.tpatch"
    ),
    env.DB.prepare(
      `
        INSERT INTO patches (
          id,
          app_id,
          platform,
          to_release_id,
          asset_id,
          from_version_code,
          old_sha256,
          patch_sha256,
          patch_size_bytes,
          output_sha256,
          output_size_bytes
        )
        VALUES (?, ?, 'android', ?, ?, 100, ?, ?, 1000, ?, 123456)
      `
    ).bind(`patch_${releaseId}`, appId, releaseId, assetId, OLD_SHA, PATCH_SHA, OUTPUT_SHA)
  ]);
}

async function seedChannel(
  appId: string,
  releaseId: string | null,
  revision: number,
  options: { disableLatest?: 0 | 1; disableDownloads?: 0 | 1 } = {}
): Promise<string> {
  const channelId = `ch_${appId}_android_stable`;
  await env.DB.prepare(
    `
      INSERT INTO channels (
        id,
        app_id,
        platform,
        name,
        current_release_id,
        revision,
        disable_latest,
        disable_downloads
      )
      VALUES (?, ?, 'android', 'stable', ?, ?, ?, ?)
    `
  )
    .bind(channelId, appId, releaseId, revision, options.disableLatest ?? 0, options.disableDownloads ?? 0)
    .run();
  return channelId;
}

async function historyCount(channelId: string): Promise<number> {
  const row = await env.DB.prepare(
    "SELECT COUNT(*) AS count FROM channel_history WHERE channel_id = ?"
  )
    .bind(channelId)
    .first<{ count: number }>();
  return row?.count ?? 0;
}

async function tokenQuery(assetId: string, releaseId: string): Promise<string> {
  const expiresAt = Math.floor(Date.now() / 1000) + 300;
  const signature = await signDownloadToken(
    env,
    "GET",
    assetId,
    releaseId,
    expiresAt,
    env.DOWNLOAD_TOKEN_KEY_VERSION
  );
  return new URLSearchParams({
    assetId,
    releaseId,
    expiresAt: String(expiresAt),
    keyVersion: env.DOWNLOAD_TOKEN_KEY_VERSION,
    signature
  }).toString();
}

function appIdFor(testName: string): string {
  return `trace_${testName}_${crypto.randomUUID().replaceAll("-", "")}`;
}
