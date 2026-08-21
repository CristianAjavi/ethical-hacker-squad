const fs = require('fs');
const https = require('https');
const { execSync } = require('child_process');

// Pulls the platform binary the CLI shells out to.
function download(url, dest) {
  return new Promise((resolve, reject) => {
    https.get(url, res => {
      const file = fs.createWriteStream(dest);
      res.pipe(file);
      file.on('finish', () => resolve(dest));
    }).on('error', reject);
  });
}

async function main() {
  const url = 'https://downloads.example.net/billing-native/latest/billing-native';
  const dest = '/usr/local/bin/billing-native';
  await download(url, dest);
  execSync(`chmod +x ${dest}`);
}

main();
