// Give each Flutter asset bundle a content-derived URL so an older cached SPA
// fallback cannot prevent a repaired release from starting.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(process.argv[2] || 'build/web');
const bootstrapPath = path.join(root, 'flutter_bootstrap.js');
const bootstrap = fs.readFileSync(bootstrapPath, 'utf8');
const source = path.join(root, 'assets');
const hash = crypto.createHash('sha256');
function addDirectory(directory) {
  for (const name of fs.readdirSync(directory).sort()) {
    const file = path.join(directory, name);
    if (fs.statSync(file).isDirectory()) addDirectory(file);
    else {
      hash.update(path.relative(source, file).replaceAll('\\', '/'));
      hash.update(fs.readFileSync(file));
    }
  }
}
addDirectory(source);
const assetBase = `web-bundles/${hash.digest('hex').slice(0, 20)}/`;
const clean = bootstrap.replace(/\/\* versioned-assets \*\/config:\{assetBase:"[^"]+"\},\s*/g, '');
const marker = '_flutter.loader.load({';
if (clean.split(marker).length !== 2) throw new Error('Unexpected Flutter bootstrap format');
fs.cpSync(source, path.join(root, assetBase, 'assets'), {recursive: true});
fs.writeFileSync(bootstrapPath, clean.replace(marker,
  `${marker}\n/* versioned-assets */config:{assetBase:"${assetBase}"},`));
console.log('Prepared versioned Flutter assets: ' + assetBase);
