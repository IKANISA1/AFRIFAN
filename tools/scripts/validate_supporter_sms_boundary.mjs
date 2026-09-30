#!/usr/bin/env node
// Keep the existing public command; XML parsing and shared-package checks live in Python.
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const script = fileURLToPath(new URL('./validate_supporter_sms_boundary.py', import.meta.url));
const result = spawnSync('python3', [script, ...process.argv.slice(2)], {stdio:'inherit'});
if(result.error) { console.error(`Supporter SMS validator could not start: ${result.error.message}`); process.exit(2); }
process.exit(result.status ?? 2);
