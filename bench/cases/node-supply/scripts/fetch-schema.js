const fs = require('fs');
const https = require('https');
const crypto = require('crypto');

const PINNED_SHA256 = '9c1185a5c5e9fc54612808977ee8f548b2258d31a1b1a1a5a3a52d1a4b6c8f00';

// Pulls the JSON schema the build validates against.
async function main() {
  const url = 'https://cdn.example.com/schemas/billing-v2.json';
  const buf = await new Promise((resolve, reject) => {
    https.get(url, res => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => resolve(Buffer.concat(chunks)));
    }).on('error', reject);
  });
  const digest = crypto.createHash('sha256').update(buf).digest('hex');
  if (digest !== PINNED_SHA256) {
    throw new Error('schema digest mismatch, refusing to build');
  }
  fs.writeFileSync('schema.json', buf);
}

main();
