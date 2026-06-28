import { ApiError, invalidParameter } from "./errors";
import { canonicalJson, verifyBearerToken } from "./crypto";
import { json } from "./http";
import { requireInt, requireSha256, requireString } from "./validation";
import type { Platform, SecurityPayload, WorkerEnv } from "./types";

interface RegisterAsset {
  assetType: "apk" | "windows_zip" | "windows_exe" | "manifest" | "patch";
  fileName: string;
  sha256: string;
  sizeBytes: number;
  githubUrl: string;
  r2Key?: string;
}

interface RegisterPatch {
  fromVersionCode: number;
  oldSha256: string;
  patchAssetName: string;
  patchSha256: string;
  patchSizeBytes: number;
  outputSha256: string;
  outputSizeBytes: number;
}

interface RegisterReleaseRequest {
  appId: string;
  platform: Platform;
  releaseTag: string;
  runId: string;
  commitSha: string;
  versionName: string;
  versionCode: number;
  releaseNotes: string;
  minClientVersionCode: number;
  capabilities: string[];
  payloadSignature: unknown;
  isFormalRelease: boolean;
  fixedSigningConfigured: boolean;
  assets: RegisterAsset[];
  patches: RegisterPatch[];
}

export async function handleRegisterRelease(
  request: Request,
  env: WorkerEnv,
  requestId: string
): Promise<Response> {
  const token = bearerToken(request);
  const authorized = await verifyBearerToken(token, env.DEPLOY_TOKEN_SHA256);
  if (!authorized) {
    throw new ApiError("TOKEN_INVALID", "CI deploy token is invalid", 401);
  }

  const input = parseRegisterReleaseRequest(await request.json());
  if (!input.isFormalRelease) {
    throw new ApiError("FORMAL_RELEASE_REQUIRED", "Cloudflare candidates require a formal release", 403);
  }
  if (input.platform === "android" && !input.fixedSigningConfigured) {
    throw new ApiError(
      "SIGNING_REQUIRED",
      "Android Cloudflare candidates require fixed release signing",
      409
    );
  }
  const payloadSignature = normalizePayloadSignature(input.payloadSignature);

  validateAssets(input, env);
  const releaseId = releaseIdFor(input.appId, input.platform, input.releaseTag);
  const existing = await env.DB.prepare(
    "SELECT id, run_id, commit_sha FROM releases WHERE app_id = ? AND platform = ? AND release_tag = ? LIMIT 1"
  )
    .bind(input.appId, input.platform, input.releaseTag)
    .first<{ id: string; run_id: string; commit_sha: string }>();
  if (existing) {
    if (existing.run_id === input.runId && existing.commit_sha === input.commitSha) {
      return json({ ok: true, releaseId: existing.id, idempotent: true });
    }
    throw invalidParameter("releaseTag already exists with different runId or commitSha");
  }

  const securityPayload = buildSecurityPayload(input);
  const statements: D1PreparedStatement[] = [
    env.DB.prepare("INSERT OR IGNORE INTO apps (id, name) VALUES (?, ?)").bind(
      input.appId,
      input.appId
    ),
    env.DB.prepare("INSERT OR IGNORE INTO app_config (app_id) VALUES (?)").bind(input.appId),
    env.DB.prepare(
      "INSERT OR IGNORE INTO channels (id, app_id, platform, name) VALUES (?, ?, ?, 'stable')"
    ).bind(channelIdFor(input.appId, input.platform, "stable"), input.appId, input.platform),
    env.DB.prepare(
      "INSERT OR IGNORE INTO channels (id, app_id, platform, name) VALUES (?, ?, ?, 'beta')"
    ).bind(channelIdFor(input.appId, input.platform, "beta"), input.appId, input.platform),
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
          capabilities_json
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'candidate', ?, ?, ?, ?, ?)
      `
    ).bind(
      releaseId,
      input.appId,
      input.platform,
      input.versionName,
      input.versionCode,
      input.releaseTag,
      input.commitSha,
      input.runId,
      JSON.stringify(payloadSignature),
      canonicalJson(securityPayload),
      input.releaseNotes,
      input.minClientVersionCode,
      JSON.stringify(input.capabilities)
    )
  ];

  for (const asset of input.assets) {
    statements.push(
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
            r2_key,
            r2_state,
            github_url
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'not_uploaded', ?)
        `
      ).bind(
        assetIdFor(releaseId, asset.assetType, asset.fileName),
        releaseId,
        input.appId,
        input.platform,
        asset.assetType,
        asset.fileName,
        asset.sha256,
        asset.sizeBytes,
        asset.r2Key ?? null,
        asset.githubUrl
      )
    );
  }

  for (const patch of input.patches) {
    const assetId = assetIdFor(releaseId, "patch", patch.patchAssetName);
    statements.push(
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
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `
      ).bind(
        patchIdFor(releaseId, patch.fromVersionCode, patch.oldSha256),
        input.appId,
        input.platform,
        releaseId,
        assetId,
        patch.fromVersionCode,
        patch.oldSha256,
        patch.patchSha256,
        patch.patchSizeBytes,
        patch.outputSha256,
        patch.outputSizeBytes
      )
    );
  }

  statements.push(
    env.DB.prepare(
      `
        INSERT INTO audit_logs (
          id,
          app_id,
          actor,
          actor_type,
          action,
          target_type,
          target_id,
          request_id,
          after_json
        )
        VALUES (?, ?, 'github-actions', 'ci', 'register_candidate', 'release', ?, ?, ?)
      `
    ).bind(crypto.randomUUID(), input.appId, releaseId, requestId, canonicalJson(securityPayload))
  );

  await env.DB.batch(statements);
  return json({ ok: true, releaseId, idempotent: false }, 201);
}

function parseRegisterReleaseRequest(value: unknown): RegisterReleaseRequest {
  if (!value || typeof value !== "object") {
    throw invalidParameter("request body must be an object");
  }
  const body = value as Record<string, unknown>;
  const platform = body.platform === "android" || body.platform === "windows" ? body.platform : null;
  if (!platform) throw invalidParameter("platform must be android or windows");

  const assets = Array.isArray(body.assets) ? body.assets.map(parseAsset) : [];
  const patches = Array.isArray(body.patches) ? body.patches.map(parsePatch) : [];
  return {
    appId: requireString(body.appId, "appId"),
    platform,
    releaseTag: requireString(body.releaseTag, "releaseTag"),
    runId: requireString(body.runId, "runId"),
    commitSha: requireString(body.commitSha, "commitSha"),
    versionName: requireString(body.versionName, "versionName"),
    versionCode: requireInt(body.versionCode, "versionCode"),
    releaseNotes: String(body.releaseNotes ?? ""),
    minClientVersionCode: body.minClientVersionCode
      ? requireInt(body.minClientVersionCode, "minClientVersionCode")
      : 0,
    capabilities: Array.isArray(body.capabilities) ? body.capabilities.map(String) : [],
    payloadSignature: body.payloadSignature,
    isFormalRelease: body.isFormalRelease === true,
    fixedSigningConfigured: body.fixedSigningConfigured === true,
    assets,
    patches
  };
}

function parseAsset(value: unknown): RegisterAsset {
  if (!value || typeof value !== "object") throw invalidParameter("asset must be an object");
  const body = value as Record<string, unknown>;
  const assetType = body.assetType;
  if (
    assetType !== "apk" &&
    assetType !== "windows_zip" &&
    assetType !== "windows_exe" &&
    assetType !== "manifest" &&
    assetType !== "patch"
  ) {
    throw invalidParameter("assetType is invalid");
  }
  return {
    assetType,
    fileName: requireString(body.fileName, "fileName"),
    sha256: requireSha256(body.sha256, "sha256"),
    sizeBytes: requireInt(body.sizeBytes, "sizeBytes"),
    githubUrl: requireString(body.githubUrl, "githubUrl"),
    r2Key: typeof body.r2Key === "string" ? body.r2Key : undefined
  };
}

function parsePatch(value: unknown): RegisterPatch {
  if (!value || typeof value !== "object") throw invalidParameter("patch must be an object");
  const body = value as Record<string, unknown>;
  return {
    fromVersionCode: requireInt(body.fromVersionCode, "fromVersionCode"),
    oldSha256: requireSha256(body.oldSha256, "oldSha256"),
    patchAssetName: requireString(body.patchAssetName, "patchAssetName"),
    patchSha256: requireSha256(body.patchSha256, "patchSha256"),
    patchSizeBytes: requireInt(body.patchSizeBytes, "patchSizeBytes"),
    outputSha256: requireSha256(body.outputSha256, "outputSha256"),
    outputSizeBytes: requireInt(body.outputSizeBytes, "outputSizeBytes")
  };
}

function validateAssets(input: RegisterReleaseRequest, env: WorkerEnv): void {
  if (input.platform === "android" && !input.assets.some((asset) => asset.assetType === "apk")) {
    throw invalidParameter("android candidate requires an APK asset");
  }
  for (const asset of input.assets) {
    assertImmutableGitHubAssetUrl(asset.githubUrl, env, input.releaseTag);
  }
}

function buildSecurityPayload(input: RegisterReleaseRequest): SecurityPayload {
  const apk = input.assets.find((asset) => asset.assetType === "apk");
  return {
    appId: input.appId,
    platform: input.platform,
    versionName: input.versionName,
    versionCode: input.versionCode,
    releaseTag: input.releaseTag,
    apkAssetName: apk?.fileName ?? "",
    apkSha256: apk?.sha256 ?? "",
    apkSize: apk?.sizeBytes ?? 0,
    patches: input.patches.map((patch) => ({
      fromVersionCode: patch.fromVersionCode,
      toVersionCode: input.versionCode,
      assetName: patch.patchAssetName,
      sha256: patch.patchSha256,
      size: patch.patchSizeBytes,
      oldSha256: patch.oldSha256,
      newSha256: patch.outputSha256
    })),
    assetHashes: input.assets.map((asset) => ({
      assetType: asset.assetType,
      fileName: asset.fileName,
      sha256: asset.sha256,
      size: asset.sizeBytes
    })),
    minClientVersionCode: input.minClientVersionCode,
    capabilities: input.capabilities
  };
}

function normalizePayloadSignature(value: unknown): Record<string, unknown> {
  if (typeof value === "string" && value.trim() !== "") {
    return { algorithm: "ed25519", keyVersion: "default", signature: value.trim() };
  }
  if (value && typeof value === "object" && !Array.isArray(value)) {
    const signature = value as Record<string, unknown>;
    if (typeof signature.signature === "string" || typeof signature.value === "string") {
      return signature;
    }
  }
  throw invalidParameter("payloadSignature is required");
}

function assertImmutableGitHubAssetUrl(value: string, env: WorkerEnv, releaseTag: string): void {
  if (value.includes("/latest/download/")) {
    throw invalidParameter("GitHub latest download URLs are not allowed");
  }
  const url = new URL(value);
  if (url.hostname !== "github.com") {
    throw invalidParameter("Phase 1 assets must use github.com immutable release URLs");
  }
  const expectedPrefix = `/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/releases/download/`;
  if (!url.pathname.startsWith(expectedPrefix) || !url.pathname.includes(`/${releaseTag}/`)) {
    throw invalidParameter("GitHub asset URL must match releaseTag");
  }
}

function bearerToken(request: Request): string | null {
  const authorization = request.headers.get("Authorization");
  if (authorization?.startsWith("Bearer ")) return authorization.slice("Bearer ".length);
  return request.headers.get("X-Deploy-Token");
}

function releaseIdFor(appId: string, platform: Platform, releaseTag: string): string {
  return `rel_${slug(appId)}_${platform}_${slug(releaseTag)}`;
}

function channelIdFor(appId: string, platform: Platform, channel: string): string {
  return `ch_${slug(appId)}_${platform}_${channel}`;
}

function assetIdFor(releaseId: string, assetType: RegisterAsset["assetType"], fileName: string): string {
  return `asset_${releaseId}_${assetType}_${slug(fileName)}`;
}

function patchIdFor(releaseId: string, fromVersionCode: number, oldSha256: string): string {
  return `patch_${releaseId}_${fromVersionCode}_${oldSha256.slice(0, 16)}`;
}

function slug(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
}
