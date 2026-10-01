// Refuse an incomplete Flutter bundle before Hosting's SPA fallback hides missing assets.
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(process.argv[2] || 'build/web');
function requireFile(relative) {
  const file = path.resolve(root, relative);
  if (!file.startsWith(root + path.sep) || !fs.statSync(file).isFile() ||
      fs.statSync(file).size === 0) {
    throw new Error(`Missing or invalid web asset: ${relative}`);
  }
  return file;
}

try {
  for (const file of ['index.html', 'flutter_bootstrap.js', 'main.dart.js',
    'manifest.json', 'assets/AssetManifest.bin.json']) requireFile(file);
  JSON.parse(fs.readFileSync(requireFile('manifest.json'), 'utf8'));
  JSON.parse(fs.readFileSync(requireFile('assets/AssetManifest.bin.json'), 'utf8'));
  const fonts = JSON.parse(fs.readFileSync(requireFile('assets/FontManifest.json'), 'utf8'));
  for (const family of fonts) {
    for (const font of family.fonts) requireFile(`assets/${font.asset}`);
  }
  const bootstrap = fs.readFileSync(requireFile('flutter_bootstrap.js'), 'utf8');
  const versioned = bootstrap.match(/\/\* versioned-assets \*\/config:\{assetBase:"([^"]+)"\}/);
  if (versioned) {
    requireFile(`${versioned[1]}assets/AssetManifest.bin.json`);
    requireFile(`${versioned[1]}assets/FontManifest.json`);
    for (const family of fonts) {
      for (const font of family.fonts) requireFile(`${versioned[1]}assets/${font.asset}`);
    }
  }
  console.log('Flutter web bundle and declared fonts verified.');
} catch (error) {
  console.error(`Web deployment blocked: ${error.message}`);
  process.exitCode = 1;
}
