#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const root = process.argv[2] ? path.resolve(process.argv[2]) : process.cwd();
const expectedApps = ['rayon_sports','vitalo','as_vita','nkana','costa_do_sol'];
const forbiddenPermissions = new Set([
  'android.permission.READ_SMS','android.permission.RECEIVE_SMS','android.permission.SEND_SMS',
  'android.permission.READ_CALL_LOG','android.permission.READ_PHONE_STATE',
]);
const forbiddenRuntime = [
  /Telephony\.Sms/i,/SmsManager/i,/SMS_RECEIVED/i,/querySms/i,/sms collector/i,
  /device[-_ ]message/i,/background[^\n]{0,40}sms/i,
];
const errors=[];
for (const slug of expectedApps) {
  const app=path.join(root,'apps',slug);
  if (!fs.existsSync(app)) { errors.push(`missing supported app: ${slug}`); continue; }
  const manifest=path.join(app,'android/app/src/main/AndroidManifest.xml');
  if (!fs.existsSync(manifest)) { errors.push(`${slug}: missing Android manifest`); continue; }
  const xml=fs.readFileSync(manifest,'utf8');
  for (const permission of forbiddenPermissions) if (xml.includes(permission)) errors.push(`${slug}: forbidden supporter permission ${permission}`);
  for (const base of ['lib','android/app/src/main']) {
    const start=path.join(app,base); if (!fs.existsSync(start)) continue;
    const stack=[start]; while(stack.length) { const current=stack.pop();
      for(const e of fs.readdirSync(current,{withFileTypes:true})) { const p=path.join(current,e.name);
        if(e.isDirectory()) stack.push(p); else if(/\.(dart|kt|java|xml)$/.test(e.name)) {
          const source=fs.readFileSync(p,'utf8'); for(const re of forbiddenRuntime) if(re.test(source)) errors.push(`${slug}: supporter SMS/device-message runtime reference in ${path.relative(root,p)}`);
        }
      }
    }
  }
}
if(errors.length){console.error(errors.join('\n'));process.exit(1)}
console.log(`Supporter SMS boundary passed for ${expectedApps.length} club apps.`);
