const fetch = require('node-fetch');
const ALLOWED = new Set(['assets.example.com']);

// The fetch used by the planted SSRF: no allowlist, follows redirects.
async function fetchLogo(url) {
  const response = await fetch(url, { redirect: 'follow' });
  return Buffer.from(await response.arrayBuffer());
}

// Decoy: an allowlist checked after resolution, redirects disabled.
async function fetchAsset(url) {
  const parsed = new URL(url);
  if (!ALLOWED.has(parsed.hostname)) throw new Error('host not allowed');
  const response = await fetch(parsed.toString(), { redirect: 'error' });
  return Buffer.from(await response.arrayBuffer());
}

module.exports = { fetchLogo, fetchAsset };
