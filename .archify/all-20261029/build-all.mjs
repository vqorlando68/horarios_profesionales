import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

const cli = '.agents/skills/archify/bin/archify.mjs';
const base = 'horario-profesionales/.archify/all-20261029';
const outDir = 'horario-profesionales/public/archify';

const items = [
  ['dataflow', `${base}/dataflow.json`, `${outDir}/dataflow.html`, 'standard'],
  ['erd', `${base}/erd.json`, `${outDir}/erd.html`, 'standard']
];

for (const [type, input, output, quality] of items) {
  console.log(`Rendering ${type}...`);
  try {
    execFileSync(process.execPath, [cli, 'deliver', type, input, output, '--quality', quality, '--json'], {
      stdio: 'pipe'
    });
    console.log(`  OK: ${output}`);
  } catch (err) {
    console.error(`  FAIL ${type}:`, err.stdout?.toString() || err.stderr?.toString() || err.message);
  }
}
