#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export function validateEconomics(record, { release = false } = {}) {
  const errors = [];
  if (!record || record.schemaVersion !== 1 || !['unresolved', 'approved'].includes(record.status)) {
    return ['Invalid economics decision record'];
  }
  if (record.status === 'unresolved') {
    if (record.transactionalMigrationEnabled !== false || record.releaseAuthorized !== false ||
        !Array.isArray(record.approvals) || record.approvals.length !== 0) {
      errors.push('An unresolved contract cannot carry approvals or enable transactional migration/release');
    }
    if (release) errors.push('Accountable economics decision is unresolved');
  } else {
    if (!['free_reward_only', 'closed_loop_entry'].includes(record.mechanic)) errors.push('Explicit supported mechanic required');
    if (!Number.isSafeInteger(record.entryDebitFet) || record.entryDebitFet < 0 || record.entryDebitMoney !== 0) {
      errors.push('Explicit nonnegative integer FET amount and zero money debit required');
    }
    if (record.mechanic === 'free_reward_only' && record.entryDebitFet !== 0) errors.push('Free entry cannot debit FET');
    if (typeof record.versionedDecisionRef !== 'string' || !record.versionedDecisionRef.trim()) errors.push('Versioned decision reference required');
    const approvals = Array.isArray(record.approvals) ? record.approvals : [];
    for (const role of ['product', 'legal', 'payments', 'store-release']) {
      const matches = approvals.filter(a => a?.role === role);
      if (matches.length !== 1 || typeof matches[0].reviewer !== 'string' || !matches[0].reviewer.trim() ||
          typeof matches[0].evidenceRef !== 'string' || !matches[0].evidenceRef.trim()) errors.push(`Missing or ambiguous approval evidence: ${role}`);
    }
    if (release && record.releaseAuthorized !== true) errors.push('Release authorization absent');
  }
  return errors;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = process.argv.slice(2); const release = args.includes('--release');
    const files = args.filter(a => !a.startsWith('--'));
    if (files.length > 1 || args.some(a => a.startsWith('--') && a !== '--release')) throw new Error('Usage: validator [decision.json] [--release]');
    const path = files[0] ?? 'docs/governance/predict-economics.json';
    const record = JSON.parse(readFileSync(path, 'utf8')); const errors = validateEconomics(record, { release });
    if (errors.length) throw new Error(errors.join('\n'));
    console.log(`Economics record consistency passed; status=${record.status}. This check does not authenticate approvals or authorize deployment.`);
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
