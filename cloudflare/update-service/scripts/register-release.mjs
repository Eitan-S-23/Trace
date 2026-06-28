#!/usr/bin/env node

import { readFile } from "node:fs/promises";

const serviceUrl = process.env.TRACE_UPDATE_SERVICE_URL;
const deployToken = process.env.TRACE_DEPLOY_TOKEN;
const metadataPath = process.argv[2] ?? process.env.TRACE_RELEASE_METADATA_JSON;

if (!serviceUrl || !deployToken || !metadataPath) {
  process.stderr.write(
    "Usage: TRACE_UPDATE_SERVICE_URL=<url> TRACE_DEPLOY_TOKEN=<token> node scripts/register-release.mjs metadata.json\n"
  );
  process.exit(2);
}

const metadata = JSON.parse(await readFile(metadataPath, "utf8"));
const response = await fetch(new URL("/api/ci/releases", serviceUrl), {
  method: "POST",
  headers: {
    Authorization: `Bearer ${deployToken}`,
    "Content-Type": "application/json"
  },
  body: JSON.stringify(metadata)
});

const body = await response.text();
if (!response.ok) {
  process.stderr.write(`Cloudflare candidate registration failed: HTTP ${response.status}\n`);
  process.stderr.write(`${body}\n`);
  process.exit(1);
}

process.stdout.write(`${body}\n`);
