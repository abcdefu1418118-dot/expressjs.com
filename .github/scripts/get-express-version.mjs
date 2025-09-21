#!/usr/bin/env node
import fs from 'fs/promises';
import { fileURLToPath } from 'url';
import path from 'path';

// This script writes the current express version to a YAML-ish file under
// .github/scripts/. It prefers reading the package.json in-tree but will
// fall back to querying the npm registry if necessary.

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..', '..', '..');

async function readLocalPackage() {
  try {
    const pkgPath = path.join(repoRoot, 'package.json');
    const data = await fs.readFile(pkgPath, 'utf8');
    const pkg = JSON.parse(data);
    if (pkg && pkg.dependencies && pkg.dependencies.express) return pkg.dependencies.express;
    if (pkg && pkg.devDependencies && pkg.devDependencies.express) return pkg.devDependencies.express;
    return pkg.version || null;
  } catch (err) {
    return null;
  }
}

async function fetchFromNpm() {
  try {
    const res = await fetch('https://registry.npmjs.org/express');
    if (!res.ok) throw new Error('npm registry fetch failed');
    const data = await res.json();
    return data['dist-tags'] && data['dist-tags'].latest ? data['dist-tags'].latest : null;
  } catch (err) {
    return null;
  }
}

(async function main(){
  let ver = await readLocalPackage();
  if (!ver) ver = await fetchFromNpm();
  if (!ver) {
    console.error('Could not determine express version');
    process.exit(2);
  }

  // write a simple file with the resolved version
  const out = path.join(repoRoot, '.github', 'scripts', 'express-version.txt');
  await fs.writeFile(out, String(ver) + '\n', 'utf8');
  console.log('Wrote express version to', out);
})();
