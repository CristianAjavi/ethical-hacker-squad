const fetch = require('node-fetch');
const ALLOWED = new Set(['assets.example.com']);

// Fetches the logo the customer pointed at.
async function fetchLogo(url) {
  const response = await fetch(url, { redirect: 'follow' });
  return Buffer.from(await response.arrayBuffer());
}

// Fetches a first-party asset by URL.
async function fetchAsset(url) {
  const parsed = new URL(url);
  if (!ALLOWED.has(parsed.hostname)) throw new Error('host not allowed');
  const response = await fetch(parsed.toString(), { redirect: 'error' });
  return Buffer.from(await response.arrayBuffer());
}

module.exports = { fetchLogo, fetchAsset };
