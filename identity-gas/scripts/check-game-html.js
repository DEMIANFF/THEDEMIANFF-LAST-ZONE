const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const repositoryRoot = path.resolve(__dirname, '../..');
const htmlPath = path.join(repositoryRoot, 'app/src/main/assets/index.html');
const html = fs.readFileSync(htmlPath, 'utf8').replace(/\r\n?/g, '\n');
const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)];
let checked = 0;

for (const [index, match] of scripts.entries()) {
  const attributes = match[1];
  const source = match[2];
  if (/\bsrc\s*=/.test(attributes) || /\btype\s*=\s*["'](?:application\/json|importmap)["']/i.test(attributes) || !source.trim()) continue;
  try {
    new vm.Script(source, { filename: `index.html:inline-script-${index + 1}` });
    checked++;
  } catch (error) {
    process.stderr.write(`${error.stack || `${error.name}: ${error.message}`}\n`);
    process.stderr.write(`Invalid inline JavaScript in ${path.relative(repositoryRoot, htmlPath)}, script ${index + 1}.\n`);
    process.exitCode = 1;
    break;
  }
}

if (!process.exitCode) console.log(`Syntax checked ${checked} inline JavaScript block(s).`);
