type Platform = "android" | "windows";
type ChannelName = "stable" | "beta";
type ActorRole = "viewer" | "publisher" | "owner";

interface AdminEnv {
  DB: D1Database;
  ENVIRONMENT: string;
  APP_ID: string;
  ACCESS_JWT_ISSUER?: string;
  ACCESS_JWT_AUD?: string;
  ADMIN_VIEWER_EMAILS?: string;
  ADMIN_PUBLISHER_EMAILS?: string;
  ADMIN_OWNER_EMAILS?: string;
  ADMIN_ALLOWED_ORIGINS?: string;
}

interface Actor {
  email: string;
  role: ActorRole;
  requestId: string;
}

interface ChannelRow {
  id: string;
  app_id: string;
  platform: Platform;
  name: ChannelName;
  current_release_id: string | null;
  revision: number;
  disable_latest: number;
  disable_downloads: number;
  maintenance_admin_only: number;
  maintenance_message: string | null;
}

interface ReleaseRow {
  id: string;
  app_id: string;
  platform: Platform;
  version_name: string;
  version_code: number;
  release_tag: string;
  state: "candidate" | "disabled";
  release_notes: string;
  archived: number;
  fallback_only: number;
}

interface AccessJwk {
  kid: string;
  kty: string;
  alg?: string;
  use?: string;
  n?: string;
  e?: string;
}

interface AccessJwks {
  keys: AccessJwk[];
}

class AdminError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly status: number
  ) {
    super(message);
    this.name = "AdminError";
  }
}

let cachedJwks: { issuer: string; expiresAt: number; jwks: AccessJwks } | null = null;

export const onRequest: PagesFunction<AdminEnv> = async (context) => {
  const requestId = requestIdFrom(context.request);
  try {
    const actor = await requireAccessActor(context.request, context.env, requestId);
    const response = await routeAdminRequest(context, actor);
    response.headers.set("X-Request-Id", requestId);
    return response;
  } catch (error) {
    const response = errorJson(error, requestId);
    response.headers.set("X-Request-Id", requestId);
    return response;
  }
};

async function routeAdminRequest(
  context: EventContext<AdminEnv, string, unknown>,
  actor: Actor
): Promise<Response> {
  const url = new URL(context.request.url);
  const method = context.request.method.toUpperCase();
  const route = routeSegments(context.params.path);

  if (method === "OPTIONS") {
    return new Response(null, { status: 204 });
  }

  if (method !== "GET") {
    requireSameOriginMutation(context.request, context.env);
    requireCsrf(context.request);
  }

  if (method === "GET" && route.length === 1 && route[0] === "session") {
    const csrfToken = crypto.randomUUID();
    return json(
      {
        ok: true,
        environment: context.env.ENVIRONMENT,
        appId: context.env.APP_ID,
        actor: actor.email,
        role: actor.role,
        csrfToken
      },
      200,
      {
        "Set-Cookie": csrfCookie(csrfToken)
      }
    );
  }

  if (method === "GET" && route.length === 1 && route[0] === "channels") {
    requireRole(actor, "viewer");
    return listChannels(context.env, url);
  }

  if (method === "GET" && route.length === 1 && route[0] === "releases") {
    requireRole(actor, "viewer");
    return listReleases(context.env, url);
  }

  if (
    method === "POST" &&
    route.length === 3 &&
    route[0] === "channels" &&
    route[2] === "publish"
  ) {
    const channel = parseChannel(route[1]);
    requireRole(actor, channel === "stable" ? "owner" : "publisher");
    const body = await requestJson(context.request);
    return publishRelease(context.env, actor, channel, body);
  }

  if (
    method === "POST" &&
    route.length === 3 &&
    route[0] === "releases" &&
    route[2] === "notes"
  ) {
    requireRole(actor, "publisher");
    const body = await requestJson(context.request);
    return editReleaseNotes(context.env, actor, route[1], body);
  }

  if (
    method === "POST" &&
    route.length === 3 &&
    route[0] === "releases" &&
    route[2] === "disable"
  ) {
    requireRole(actor, "owner");
    return disableRelease(context.env, actor, route[1]);
  }

  throw new AdminError("NOT_FOUND", "Admin route not found", 404);
}

async function listChannels(env: AdminEnv, url: URL): Promise<Response> {
  const appId = queryString(url, "appId") ?? env.APP_ID;
  const platform = parsePlatform(queryString(url, "platform") ?? "android");
  const result = await env.DB.prepare(
    `
      SELECT
        c.*,
        r.release_tag,
        r.version_name,
        r.version_code,
        r.state AS release_state
      FROM channels c
      LEFT JOIN releases r ON r.id = c.current_release_id
      WHERE c.app_id = ? AND c.platform = ?
      ORDER BY c.name
    `
  )
    .bind(appId, platform)
    .all();
  return json({ ok: true, channels: result.results });
}

async function listReleases(env: AdminEnv, url: URL): Promise<Response> {
  const appId = queryString(url, "appId") ?? env.APP_ID;
  const platform = parsePlatform(queryString(url, "platform") ?? "android");
  const result = await env.DB.prepare(
    `
      SELECT
        r.*,
        group_concat(c.name) AS published_channels,
        (
          SELECT count(*)
          FROM release_assets a
          WHERE a.release_id = r.id AND a.disabled = 0
        ) AS asset_count,
        (
          SELECT count(*)
          FROM release_assets a
          WHERE a.release_id = r.id AND a.disabled = 0 AND a.r2_state = 'available'
        ) AS r2_available_count,
        (
          SELECT count(*)
          FROM release_assets a
          WHERE a.release_id = r.id AND a.disabled = 0 AND a.r2_state <> 'available'
        ) AS github_fallback_only_count,
        (
          SELECT count(*)
          FROM patches p
          WHERE p.to_release_id = r.id AND p.disabled = 0
        ) AS patch_count
      FROM releases r
      LEFT JOIN channels c ON c.current_release_id = r.id
      WHERE r.app_id = ? AND r.platform = ?
      GROUP BY r.id
      ORDER BY r.version_code DESC, r.created_at DESC
      LIMIT 50
    `
  )
    .bind(appId, platform)
    .all();
  return json({ ok: true, releases: result.results });
}

async function publishRelease(
  env: AdminEnv,
  actor: Actor,
  channelName: ChannelName,
  body: Record<string, unknown>
): Promise<Response> {
  const appId = requireString(body.appId ?? env.APP_ID, "appId");
  const platform = parsePlatform(body.platform ?? "android");
  const releaseId = requireString(body.releaseId, "releaseId");
  const expectedRevision = requireInt(body.expectedRevision, "expectedRevision");
  const rollback = body.rollback === true;

  const channel = await env.DB.prepare(
    "SELECT * FROM channels WHERE app_id = ? AND platform = ? AND name = ? LIMIT 1"
  )
    .bind(appId, platform, channelName)
    .first<ChannelRow>();
  if (!channel) throw new AdminError("RELEASE_NOT_FOUND", "Channel not found", 404);

  const target = await env.DB.prepare("SELECT * FROM releases WHERE id = ? LIMIT 1")
    .bind(releaseId)
    .first<ReleaseRow>();
  if (!target || target.app_id !== appId || target.platform !== platform) {
    throw new AdminError("RELEASE_NOT_FOUND", "Release not found", 404);
  }
  if (target.state === "disabled") {
    throw new AdminError("RELEASE_DISABLED", "Disabled release cannot be published", 410);
  }
  if (target.archived === 1) {
    throw new AdminError("ASSET_ARCHIVED", "Archived release cannot be published", 409);
  }
  if (target.release_notes.trim() === "") {
    throw new AdminError("RELEASE_NOTES_REQUIRED", "Release notes are required before publish", 409);
  }

  if (channel.current_release_id && !rollback) {
    const current = await env.DB.prepare("SELECT version_code FROM releases WHERE id = ? LIMIT 1")
      .bind(channel.current_release_id)
      .first<{ version_code: number }>();
    if (current && target.version_code <= current.version_code) {
      throw new AdminError(
        "VERSION_REGRESSION",
        "Publishing a non-rollback versionCode regression is blocked",
        409
      );
    }
  }

  if (platform === "android") {
    await ensureAndroidCompleteness(env, releaseId);
  }

  const beforeJson = canonicalJson(channel);
  const afterJson = canonicalJson({ ...channel, current_release_id: releaseId });
  const updatedChannel = await env.DB.prepare(
    `
      UPDATE channels
      SET
        current_release_id = ?,
        revision = revision + 1,
        last_action = ?,
        last_actor = ?,
        last_actor_type = 'access',
        last_request_id = ?,
        last_before_json = ?,
        last_after_json = ?,
        updated_at = datetime('now')
      WHERE id = ? AND revision = ? AND disable_latest = 0
      RETURNING revision
    `
  )
    .bind(
      releaseId,
      rollback ? "rollback" : "publish",
      actor.email,
      actor.requestId,
      beforeJson,
      afterJson,
      channel.id,
      expectedRevision
    )
    .first<{ revision: number }>();

  if (!updatedChannel) {
    throw new AdminError("CAS_CONFLICT", "Channel revision changed or latest is disabled", 409);
  }
  return json({ ok: true, revision: updatedChannel.revision });
}

async function editReleaseNotes(
  env: AdminEnv,
  actor: Actor,
  releaseId: string,
  body: Record<string, unknown>
): Promise<Response> {
  const releaseNotes = requireString(body.releaseNotes, "releaseNotes");
  if (releaseNotes.length > 8000) {
    throw new AdminError("INVALID_PARAMETER", "releaseNotes is too long", 400);
  }

  const release = await env.DB.prepare("SELECT * FROM releases WHERE id = ? LIMIT 1")
    .bind(releaseId)
    .first<ReleaseRow>();
  if (!release) throw new AdminError("RELEASE_NOT_FOUND", "Release not found", 404);

  const beforeJson = canonicalJson({ releaseNotes: release.release_notes });
  const afterJson = canonicalJson({ releaseNotes });
  await env.DB.batch([
    env.DB.prepare("UPDATE releases SET release_notes = ?, updated_at = datetime('now') WHERE id = ?")
      .bind(releaseNotes, releaseId),
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
          before_json,
          after_json
        )
        VALUES (?, ?, ?, 'access', 'edit_notes', 'release', ?, ?, ?, ?)
      `
    ).bind(
      crypto.randomUUID(),
      release.app_id,
      actor.email,
      releaseId,
      actor.requestId,
      beforeJson,
      afterJson
    ),
    env.DB.prepare(
      `
        UPDATE channels
        SET
          revision = revision + 1,
          last_action = 'edit_notes',
          last_actor = ?,
          last_actor_type = 'access',
          last_request_id = ?,
          last_before_json = ?,
          last_after_json = ?,
          updated_at = datetime('now')
        WHERE current_release_id = ?
      `
    ).bind(actor.email, actor.requestId, beforeJson, afterJson, releaseId)
  ]);

  return json({ ok: true });
}

async function disableRelease(env: AdminEnv, actor: Actor, releaseId: string): Promise<Response> {
  const referenced = await env.DB.prepare(
    "SELECT id FROM channels WHERE current_release_id = ? LIMIT 1"
  )
    .bind(releaseId)
    .first<{ id: string }>();
  if (referenced) {
    throw new AdminError(
      "RELEASE_DISABLED",
      "Published release cannot be disabled before moving the channel",
      409
    );
  }

  const release = await env.DB.prepare("SELECT app_id, state FROM releases WHERE id = ? LIMIT 1")
    .bind(releaseId)
    .first<{ app_id: string; state: string }>();
  if (!release) throw new AdminError("RELEASE_NOT_FOUND", "Release not found", 404);

  const result = await env.DB.prepare(
    "UPDATE releases SET state = 'disabled', updated_at = datetime('now') WHERE id = ?"
  )
    .bind(releaseId)
    .run();
  if (result.meta.changes !== 1) {
    throw new AdminError("RELEASE_NOT_FOUND", "Release not found", 404);
  }

  await env.DB.prepare(
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
        before_json,
        after_json
      )
      VALUES (?, ?, ?, 'access', 'disable_release', 'release', ?, ?, ?, '{"state":"disabled"}')
    `
  )
    .bind(
      crypto.randomUUID(),
      release.app_id,
      actor.email,
      releaseId,
      actor.requestId,
      canonicalJson({ state: release.state })
    )
    .run();

  return json({ ok: true });
}

async function ensureAndroidCompleteness(env: AdminEnv, releaseId: string): Promise<void> {
  const apk = await env.DB.prepare(
    "SELECT id FROM release_assets WHERE release_id = ? AND platform = 'android' AND asset_type = 'apk' AND disabled = 0 LIMIT 1"
  )
    .bind(releaseId)
    .first<{ id: string }>();
  if (!apk) {
    throw new AdminError("BACKEND_UNAVAILABLE", "Android release is missing an APK asset", 503);
  }
}

async function requireAccessActor(
  request: Request,
  env: AdminEnv,
  requestId: string
): Promise<Actor> {
  if (!env.ACCESS_JWT_ISSUER || !env.ACCESS_JWT_AUD) {
    throw new AdminError("BACKEND_UNAVAILABLE", "Cloudflare Access is not configured", 503);
  }

  const token = request.headers.get("CF-Access-Jwt-Assertion") ?? bearerToken(request);
  if (!token) {
    throw new AdminError("TOKEN_INVALID", "Cloudflare Access JWT is required", 401);
  }

  const { header, payload, signedData, signature } = parseJwt(token);
  if (header.alg !== "RS256" || typeof header.kid !== "string") {
    throw new AdminError("TOKEN_INVALID", "Cloudflare Access JWT algorithm is invalid", 401);
  }

  const nowSeconds = Math.floor(Date.now() / 1000);
  if (typeof payload.exp !== "number" || payload.exp <= nowSeconds) {
    throw new AdminError("TOKEN_EXPIRED", "Cloudflare Access JWT expired", 401);
  }
  if (typeof payload.nbf === "number" && payload.nbf > nowSeconds) {
    throw new AdminError("TOKEN_INVALID", "Cloudflare Access JWT is not valid yet", 401);
  }
  if (payload.iss !== env.ACCESS_JWT_ISSUER) {
    throw new AdminError("TOKEN_INVALID", "Cloudflare Access JWT issuer is invalid", 401);
  }
  if (!audienceMatches(payload.aud, env.ACCESS_JWT_AUD)) {
    throw new AdminError("TOKEN_INVALID", "Cloudflare Access JWT audience is invalid", 401);
  }

  const jwk = await jwkForKid(env.ACCESS_JWT_ISSUER, header.kid);
  const key = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"]
  );
  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    arrayBufferFromBytes(signature),
    new TextEncoder().encode(signedData)
  );
  if (!valid) {
    throw new AdminError("TOKEN_INVALID", "Cloudflare Access JWT signature is invalid", 401);
  }

  const email = typeof payload.email === "string" ? payload.email.toLowerCase() : "";
  if (!email) {
    throw new AdminError("TOKEN_INVALID", "Cloudflare Access JWT email is missing", 401);
  }

  return {
    email,
    role: roleForEmail(env, email),
    requestId
  };
}

async function jwkForKid(issuer: string, kid: string): Promise<JsonWebKey> {
  const now = Date.now();
  if (!cachedJwks || cachedJwks.issuer !== issuer || cachedJwks.expiresAt <= now) {
    const response = await fetch(`${issuer.replace(/\/$/, "")}/cdn-cgi/access/certs`, {
      headers: { Accept: "application/json" }
    });
    if (!response.ok) {
      throw new AdminError("BACKEND_UNAVAILABLE", "Could not fetch Cloudflare Access certs", 503);
    }
    cachedJwks = {
      issuer,
      expiresAt: now + 5 * 60 * 1000,
      jwks: (await response.json()) as AccessJwks
    };
  }

  const key = cachedJwks.jwks.keys.find((candidate) => candidate.kid === kid);
  if (!key || key.kty !== "RSA") {
    throw new AdminError("TOKEN_INVALID", "Cloudflare Access JWT key is unknown", 401);
  }
  return key as JsonWebKey;
}

function parseJwt(token: string): {
  header: Record<string, unknown>;
  payload: Record<string, unknown>;
  signedData: string;
  signature: Uint8Array;
} {
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new AdminError("TOKEN_INVALID", "Cloudflare Access JWT is malformed", 401);
  }
  return {
    header: jsonFromBase64Url(parts[0]),
    payload: jsonFromBase64Url(parts[1]),
    signedData: `${parts[0]}.${parts[1]}`,
    signature: bytesFromBase64Url(parts[2])
  };
}

function roleForEmail(env: AdminEnv, email: string): ActorRole {
  const owners = emailSet(env.ADMIN_OWNER_EMAILS);
  const publishers = emailSet(env.ADMIN_PUBLISHER_EMAILS);
  const viewers = emailSet(env.ADMIN_VIEWER_EMAILS);
  if (owners.has(email)) return "owner";
  if (publishers.has(email)) return "publisher";
  if (viewers.has(email)) return "viewer";
  throw new AdminError("TOKEN_INVALID", "Cloudflare Access user is not allowed", 403);
}

function requireRole(actor: Actor, required: ActorRole): void {
  const rank = { viewer: 1, publisher: 2, owner: 3 } satisfies Record<ActorRole, number>;
  if (rank[actor.role] < rank[required]) {
    throw new AdminError("TOKEN_INVALID", "Admin role is not allowed for this action", 403);
  }
}

function requireSameOriginMutation(request: Request, env: AdminEnv): void {
  const origin = request.headers.get("Origin");
  const allowed = new Set([
    new URL(request.url).origin,
    ...csv(env.ADMIN_ALLOWED_ORIGINS)
  ]);
  if (!origin || !allowed.has(origin)) {
    throw new AdminError("TOKEN_INVALID", "Admin mutation origin is not allowed", 403);
  }
}

function requireCsrf(request: Request): void {
  const header = request.headers.get("X-CSRF-Token");
  const cookie = cookieValue(request.headers.get("Cookie"), "trace_admin_csrf");
  if (!header || !cookie || header !== cookie) {
    throw new AdminError("TOKEN_INVALID", "CSRF token is invalid", 403);
  }
}

async function requestJson(request: Request): Promise<Record<string, unknown>> {
  const body = await request.json().catch(() => null);
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw new AdminError("INVALID_PARAMETER", "Request body must be a JSON object", 400);
  }
  return body as Record<string, unknown>;
}

function json(data: unknown, status = 200, headers?: HeadersInit): Response {
  return Response.json(data, {
    status,
    headers: {
      "Cache-Control": "no-store",
      ...headers
    }
  });
}

function errorJson(error: unknown, requestId: string): Response {
  if (error instanceof AdminError) {
    return json({ errorCode: error.code, message: error.message, requestId }, error.status);
  }
  const message = error instanceof Error ? error.message : String(error);
  return json(
    { errorCode: "BACKEND_UNAVAILABLE", message: "Admin backend unavailable", requestId, detail: message },
    503
  );
}

function routeSegments(value: string | string[] | undefined): string[] {
  if (!value) return [];
  return Array.isArray(value) ? value : [value];
}

function requestIdFrom(request: Request): string {
  return request.headers.get("X-Request-Id") ?? crypto.randomUUID();
}

function queryString(url: URL, key: string): string | null {
  const value = url.searchParams.get(key);
  return value === "" ? null : value;
}

function requireString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim() === "") {
    throw new AdminError("INVALID_PARAMETER", `${field} is required`, 400);
  }
  return value.trim();
}

function requireInt(value: unknown, field: string): number {
  const parsed =
    typeof value === "number" ? value : typeof value === "string" ? Number(value) : NaN;
  if (!Number.isInteger(parsed) || parsed < 0) {
    throw new AdminError("INVALID_PARAMETER", `${field} must be a non-negative integer`, 400);
  }
  return parsed;
}

function parsePlatform(value: unknown): Platform {
  if (value === "android" || value === "windows") return value;
  throw new AdminError("INVALID_PARAMETER", "platform must be android or windows", 400);
}

function parseChannel(value: unknown): ChannelName {
  if (value === "stable" || value === "beta") return value;
  throw new AdminError("INVALID_PARAMETER", "channel must be stable or beta", 400);
}

function canonicalJson(value: unknown): string {
  if (Array.isArray(value)) {
    return `[${value.map((entry) => canonicalJson(entry)).join(",")}]`;
  }
  if (value && typeof value === "object") {
    return `{${Object.entries(value)
      .filter(([, entryValue]) => entryValue !== undefined)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, entryValue]) => `${JSON.stringify(key)}:${canonicalJson(entryValue)}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

function audienceMatches(aud: unknown, expected: string): boolean {
  return Array.isArray(aud) ? aud.includes(expected) : aud === expected;
}

function emailSet(value: string | undefined): Set<string> {
  return new Set(csv(value).map((entry) => entry.toLowerCase()));
}

function csv(value: string | undefined): string[] {
  return (value ?? "")
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function bearerToken(request: Request): string | null {
  const authorization = request.headers.get("Authorization");
  return authorization?.startsWith("Bearer ") ? authorization.slice("Bearer ".length) : null;
}

function jsonFromBase64Url(value: string): Record<string, unknown> {
  const text = new TextDecoder().decode(bytesFromBase64Url(value));
  const parsed = JSON.parse(text) as unknown;
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new AdminError("TOKEN_INVALID", "Cloudflare Access JWT payload is invalid", 401);
  }
  return parsed as Record<string, unknown>;
}

function bytesFromBase64Url(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function arrayBufferFromBytes(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
}

function cookieValue(cookieHeader: string | null, name: string): string | null {
  if (!cookieHeader) return null;
  for (const part of cookieHeader.split(";")) {
    const [key, ...rest] = part.trim().split("=");
    if (key === name) return rest.join("=");
  }
  return null;
}

function csrfCookie(value: string): string {
  return `trace_admin_csrf=${value}; Path=/api/admin; HttpOnly; Secure; SameSite=Strict; Max-Age=3600`;
}
