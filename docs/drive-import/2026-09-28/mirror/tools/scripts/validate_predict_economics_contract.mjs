#!/usr/bin/env node
import fs from 'node:fs';
const files = process.argv.slice(2);
if (!files.length) throw new Error('Pass governed product-policy files.');
const source = files.map((p) => fs.readFileSync(p,'utf8')).join('\n');
const required = ['free selected-match','does not debit FET','no odds'];
const missing = required.filter((x)=>!source.toLowerCase().includes(x.toLowerCase()));
if (missing.length) { console.error(`Predict economics governance incomplete: ${missing.join(', ')}`); process.exit(1); }
console.log('Predict economics governance passed: free-entry contract is explicit pending approved replacement.');
