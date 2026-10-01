import { existsSync, readFileSync, lstatSync, openSync, writeFileSync, fsyncSync, fchmodSync, closeSync, renameSync, unlinkSync, constants } from "node:fs";
import { resolve } from "node:path";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";

const keys = [
  "NEXT_PUBLIC_SITE_URL",
  "NEXT_PUBLIC_SUPABASE_URL",
  "NEXT_PUBLIC_SUPABASE_ANON_KEY",
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
];

function parseEnv(source) {
  return source
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"))
    .reduce((env, line) => {
      const separator = line.indexOf("=");
      if (separator === -1) {
        return env;
      }

      const key = line.slice(0, separator).trim();
      let value = line.slice(separator + 1).trim();

      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1);
      }

      env[key] = value;
      return env;
    }, {});
}

export function writePrivateDevVars(directory,content){
 const target=resolve(directory,'.dev.vars');
 if(existsSync(target)||(()=>{try{return lstatSync(target).isSymbolicLink();}catch{return false;}})()){
  const stat=lstatSync(target);
  if(!stat.isFile()||stat.isSymbolicLink())throw Error('unsafe_private_environment_target');
 }
 const temporary=resolve(directory,'.dev.vars-'+randomUUID());let descriptor;
 try{
  descriptor=openSync(temporary,constants.O_WRONLY|constants.O_CREAT|constants.O_EXCL|constants.O_NOFOLLOW,0o600);
  fchmodSync(descriptor,0o600);writeFileSync(descriptor,content,{encoding:'utf8'});fsyncSync(descriptor);
  closeSync(descriptor);descriptor=undefined;renameSync(temporary,target);
 }finally{
  if(descriptor!==undefined)closeSync(descriptor);
  try{unlinkSync(temporary);}catch{/* A completed rename has no temporary entry. */}
 }
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const root=resolve(process.cwd());
  const sourcePath=['.env.local','.env'].map(file=>resolve(root,file)).find(file=>existsSync(file));
  const parsed=sourcePath?parseEnv(readFileSync(sourcePath,'utf8')):{};
  const lines=['NEXTJS_ENV=development'];
  for(const key of keys){
   const value=parsed[key]??process.env[key]??'';
   if(/[\r\n\0]/.test(value))throw Error('unsafe_private_environment_input');
   if(value)lines.push(`${key}=${value}`);
  }
  writePrivateDevVars(root,`${lines.join('\n')}\n`);console.log('Wrote owner-only .dev.vars.');
 }
 catch{console.error('private_environment_write_failed');process.exitCode=1;}
}
