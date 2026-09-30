#!/usr/bin/env node
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {UUID,exactObject,positiveClub,requireThat} from '../src/errors.mjs';

/** Generate INSERT-only SQL, never execute it and never grant access.
 * Operator enrollment and enabling require a separate privileged, reviewed action.
 */
export function prepareEnrollment(input,now=Date.now()) {
  exactObject(input,['principalId','accessAccountId','accessSubject','clubId','clubSlug','sourceClubId','expiresAt','enrollmentRef']);
  requireThat(UUID.test(input.principalId)&&UUID.test(input.accessSubject),'invalid_principal');
  requireThat(/^[a-f0-9]{32}$/.test(input.accessAccountId),'invalid_account');positiveClub(input.clubId);
  requireThat(input.clubId===24&&input.clubSlug==='rayon_sports_rw','unsupported_staging_club');
  requireThat(typeof input.sourceClubId==='string'&&/^[A-Za-z0-9_-]{1,128}$/.test(input.sourceClubId),'invalid_source_club');
  requireThat(typeof input.enrollmentRef==='string'&&/^[A-Za-z0-9_.:/-]{3,160}$/.test(input.enrollmentRef),'invalid_enrollment_reference');
  const expiry=Date.parse(input.expiresAt);
  requireThat(Number.isSafeInteger(expiry)&&expiry>now&&expiry<=now+7*86400000,'invalid_enrollment_expiry');
  const q=value=>`'${String(value).replaceAll("'","''")}'`;
  return [
    '-- DISABLED ENROLLMENT PLAN ONLY. Not approval and not executed by this tool.',
    `-- Evidence reference: ${input.enrollmentRef}`,
    '-- Exact source tenant mapping and Access subject must be independently verified.',
    '-- Existing keys cause a conflict rather than changing another enrollment.',
    `INSERT INTO public_operator_tenants(club_id,club_slug,source_club_id,enabled) VALUES(24,${q(input.clubSlug)},${q(input.sourceClubId)},0);`,
    `INSERT INTO public_operator_principals(principal_id,access_account_id,access_subject,enabled) VALUES(${q(input.principalId)},${q(input.accessAccountId)},${q(input.accessSubject)},0);`,
    `INSERT INTO public_operator_grants(principal_id,club_id,can_review,can_publish,enabled,expires_at_ms) VALUES(${q(input.principalId)},24,0,0,0,${expiry});`,
    '-- Apply reviewed statements together with D1 batch or a governed migration.',
    '-- Never replace a conflict with INSERT OR REPLACE. Enabling is a separate change.',
  ].join('\n')+'\n';
}
if(import.meta.url===pathToFileURL(process.argv[1]??'').href) {
  if(process.argv.length!==3){console.error('Usage: node prepare-enrollment.mjs enrollment.private.json > plan.private.sql');process.exit(2);}
  try {process.stdout.write(prepareEnrollment(JSON.parse(readFileSync(process.argv[2],'utf8'))));}
  catch(error){console.error(error.code??'Invalid enrollment input.');process.exitCode=2;}
}
