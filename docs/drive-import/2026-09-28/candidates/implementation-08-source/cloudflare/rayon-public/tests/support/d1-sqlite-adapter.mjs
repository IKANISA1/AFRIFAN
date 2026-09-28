import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
const sqlFiles = ['0001_source_staging.sql','0002_snapshot_publication.sql','0003_immutable_public_snapshots.sql'];
export class D1Adapter {
  constructor(path = ":memory:", { migrate = true } = {}) {
    this.sqlite = new DatabaseSync(path);
    this.sqlite.exec('PRAGMA foreign_keys=ON');
    if (migrate) for (const file of sqlFiles) this.sqlite.exec(readFileSync(new URL(`../../migrations/${file}`,import.meta.url),'utf8'));
    this.failAt = null; this.sessions = []; this.queryLog = [];
  }
  withSession(constraint) { this.sessions.push(constraint); return this; }
  prepare(sql) {
    const db = this;
    return { args:[], bind(...args) { return {...this, args}; },
      async first() { db.queryLog.push(sql); return db.sqlite.prepare(sql).get(...this.args) ?? null; },
      async all() { db.queryLog.push(sql); return {results:db.sqlite.prepare(sql).all(...this.args)}; },
      async run() { db.queryLog.push(sql); const r=db.sqlite.prepare(sql).run(...this.args); return {success:true,meta:{changes:Number(r.changes)}}; },
    };
  }
  async batch(statements) {
    this.sqlite.exec('BEGIN IMMEDIATE');
    try {
      const results=[];
      for(let i=0;i<statements.length;i++) {
        if(this.failAt===i) throw new Error('injected failure');
        results.push(await statements[i].run());
      }
      this.sqlite.exec('COMMIT'); return results;
    } catch(error) { this.sqlite.exec('ROLLBACK'); throw error; }
  }
}
