/** Node-only durable operator journal used by the executable local rehearsal and private host tooling. */
import {DatabaseSync} from 'node:sqlite';
import {openSync,closeSync,lstatSync,realpathSync,existsSync} from 'node:fs';import {dirname,resolve,join,basename} from 'node:path';
const uuid=x=>typeof x==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(x);
export class LocalRecoveryJournal {
 constructor(path,{clubId,role,scopeId}){
  if(!Number.isSafeInteger(clubId)||clubId<=0||!['maker','checker'].includes(role)||!uuid(scopeId))throw Error('journal_configuration_invalid');
  const parent=realpathSync(dirname(resolve(path))),parentStat=lstatSync(parent);
  if((parentStat.mode&0o022)!==0||parentStat.uid!==process.getuid())throw Error('journal_directory_not_private');
  const file=join(parent,basename(path));if(!existsSync(file)){const fd=openSync(file,'wx',0o600);closeSync(fd);}
  const stat=lstatSync(file);if(!stat.isFile()||stat.isSymbolicLink()||stat.nlink!==1||stat.uid!==process.getuid()||(stat.mode&0o077)!==0)throw Error('journal_file_not_private');
  this.db=new DatabaseSync(file);this.db.exec('PRAGMA foreign_keys=ON;PRAGMA busy_timeout=5000;PRAGMA synchronous=FULL');
  this.db.exec(`CREATE TABLE IF NOT EXISTS recovery_journal_scope(singleton INTEGER PRIMARY KEY CHECK(singleton=1),club_id INTEGER NOT NULL,role TEXT NOT NULL,scope_id TEXT NOT NULL) STRICT;
   CREATE TABLE IF NOT EXISTS recovery_journal_head(singleton INTEGER PRIMARY KEY CHECK(singleton=1),version INTEGER NOT NULL,value_json TEXT CHECK(value_json IS NULL OR json_valid(value_json))) STRICT;
   CREATE TABLE IF NOT EXISTS recovery_journal_history(version INTEGER PRIMARY KEY,value_json TEXT NOT NULL CHECK(json_valid(value_json))) STRICT;
   CREATE TRIGGER IF NOT EXISTS recovery_journal_history_no_update BEFORE UPDATE ON recovery_journal_history BEGIN SELECT RAISE(ABORT,'journal_immutable');END;
   CREATE TRIGGER IF NOT EXISTS recovery_journal_history_no_delete BEFORE DELETE ON recovery_journal_history BEGIN SELECT RAISE(ABORT,'journal_immutable');END;
   CREATE TRIGGER IF NOT EXISTS recovery_journal_scope_no_update BEFORE UPDATE ON recovery_journal_scope BEGIN SELECT RAISE(ABORT,'journal_immutable');END;
   CREATE TRIGGER IF NOT EXISTS recovery_journal_scope_no_delete BEFORE DELETE ON recovery_journal_scope BEGIN SELECT RAISE(ABORT,'journal_immutable');END;`);
  const scope=this.db.prepare('SELECT * FROM recovery_journal_scope').get();
  if(scope&&(scope.club_id!==clubId||scope.role!==role||scope.scope_id!==scopeId)){this.db.close();throw Error('journal_scope_conflict');}
  if(!scope)this.db.prepare('INSERT INTO recovery_journal_scope VALUES(1,?,?,?)').run(clubId,role,scopeId);
  this.db.exec('INSERT INTO recovery_journal_head VALUES(1,0,NULL) ON CONFLICT(singleton) DO NOTHING');this.scope={clubId,role,scopeId};this.file=file;
 }
 async load(){const row=this.db.prepare('SELECT version,value_json FROM recovery_journal_head WHERE singleton=1').get();return {version:row.version,value:row.value_json===null?null:JSON.parse(row.value_json)};}
 async compareAndSwap(version,value){
  if(!Number.isSafeInteger(version)||version<0||value?.clubId!==this.scope.clubId||value?.role!==this.scope.role||value?.purpose!=='allocation-recovery')throw Error('journal_scope_conflict');
  const json=JSON.stringify(value);if(Buffer.byteLength(json)>16384)throw Error('journal_value_too_large');
  this.db.exec('BEGIN IMMEDIATE');try{
   const changed=this.db.prepare('UPDATE recovery_journal_head SET version=version+1,value_json=? WHERE singleton=1 AND version=?').run(json,version);
   if(Number(changed.changes)!==1){this.db.exec('ROLLBACK');return false;}
   this.db.prepare('INSERT INTO recovery_journal_history VALUES(?,?)').run(version+1,json);this.db.exec('COMMIT');return true;
  }catch{this.db.exec('ROLLBACK');throw Error('journal_unavailable');}
 }
 close(){this.db.close();}
}
