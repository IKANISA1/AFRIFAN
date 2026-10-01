import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {tmpdir} from 'node:os';
import {execFileSync} from 'node:child_process';
import {snapshotInstalledArtifactInputs,stageInstalledArtifactInputs,INSTALLED_ARTIFACT_INPUT_LIMITS} from './artifact-installed-inputs.mjs';

function fixture(t){
  const root=fs.realpathSync(fs.mkdtempSync(path.join(tmpdir(),'africlub-installed-inputs-')));
  t.after(()=>fs.rmSync(root,{recursive:true,force:true}));
  const web=path.join(root,'original'),target=path.join(root,'staged'),modules=path.join(web,'node_modules');
  fs.mkdirSync(modules,{recursive:true});fs.mkdirSync(target);
  const file=(relative,contents='synthetic dependency')=>{
    const output=path.join(modules,relative);fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,contents);return output;
  };
  return {root,web,target,modules,file};
}
const rejected=action=>assert.throws(action,error=>/^artifact_installed_input_/.test(error.code)&&error.message===error.code);

test('snapshot hashes every byte and portable path, preserves executable modes, and round trips through JSON',t=>{
  const f=fixture(t);const script=f.file('pkg/bin.js','first bytes');fs.chmodSync(script,0o755);f.file('pkg/data.json','{}');
  const snapshot=snapshotInstalledArtifactInputs(f.web);
  assert.equal(snapshot.fileCount,2);assert.equal(snapshot.directoryCount,1);assert.equal(snapshot.totalBytes,13);
  assert.deepEqual(snapshot.entries.map(item=>item.path),['pkg','pkg/bin.js','pkg/data.json']);
  const result=stageInstalledArtifactInputs(f.web,f.target,JSON.parse(JSON.stringify(snapshot)));
  assert.equal(result.verified,true);assert.equal(result.sha256,snapshot.sha256);assert.equal(result.linksToOriginalDependencies,0);
  assert.equal(fs.statSync(path.join(f.target,'node_modules/pkg/bin.js')).mode&0o777,0o755);
  assert.equal(snapshotInstalledArtifactInputs(f.target).sha256,snapshot.sha256);
  assert.notEqual(result.stagedBindingSha256,result.sourceBindingSha256);
  fs.writeFileSync(script,'other bytes');assert.notEqual(snapshotInstalledArtifactInputs(f.web).sha256,snapshot.sha256);
});

test('internal file, chained, directory and absolute links are recreated safely inside independent copied dependencies',t=>{
  const f=fixture(t),script=f.file('pkg/bin.js','synthetic executable');fs.mkdirSync(path.join(f.modules,'.bin'));
  fs.symlinkSync('../pkg/bin.js',path.join(f.modules,'.bin/tool'));
  fs.symlinkSync('tool',path.join(f.modules,'.bin/chain'));
  fs.symlinkSync('pkg',path.join(f.modules,'alias'),'dir');
  fs.symlinkSync(script,path.join(f.modules,'absolute'));
  const snapshot=snapshotInstalledArtifactInputs(f.web);
  assert.equal(snapshot.symlinkCount,4);
  for(const link of snapshot.entries.filter(item=>item.kind==='symlink'))assert.match(link.targetSha256,/^[0-9a-f]{64}$/);
  const result=stageInstalledArtifactInputs(f.web,f.target,snapshot),staged=path.join(f.target,'node_modules');
  assert.equal(result.verified,true);
  for(const link of snapshot.entries.filter(item=>item.kind==='symlink')){
    const output=path.join(staged,link.path);assert.equal(path.isAbsolute(fs.readlinkSync(output)),false);
    assert.ok(fs.realpathSync(output).startsWith(staged+path.sep));
  }
  assert.notEqual(fs.statSync(script).ino,fs.statSync(path.join(staged,'pkg/bin.js')).ino);
  fs.writeFileSync(script,'changed original');assert.equal(fs.readFileSync(path.join(staged,'.bin/chain'),'utf8'),'synthetic executable');
  assert.equal(fs.readFileSync(path.join(staged,'alias/bin.js'),'utf8'),'synthetic executable');
});

test('outside targets and a chain that temporarily escapes then returns to the tree are rejected',t=>{
  for(const chain of [false,true]){
    const f=fixture(t),inside=f.file('pkg/file.js');const outside=path.join(f.root,'outside');fs.mkdirSync(outside);
    if(chain)fs.symlinkSync(inside,path.join(outside,'back'));else fs.writeFileSync(path.join(outside,'file.js'),'outside contents');
    fs.symlinkSync(path.join(outside,chain?'back':'file.js'),path.join(f.modules,'escape'));
    rejected(()=>snapshotInstalledArtifactInputs(f.web));
  }
});

test('dangling links, link cycles, a linked dependency root and unsupported filesystem types are rejected',t=>{
  for(const target of ['missing','cycle']){
    const f=fixture(t);f.file('pkg/file.js');fs.symlinkSync(target,path.join(f.modules,'cycle'));
    rejected(()=>snapshotInstalledArtifactInputs(f.web));
  }
  const f=fixture(t);f.file('pkg/file.js');const linked=path.join(f.root,'linked');fs.mkdirSync(linked);
  fs.symlinkSync(f.modules,path.join(linked,'node_modules'),'dir');rejected(()=>snapshotInstalledArtifactInputs(linked));
  execFileSync('mkfifo',[path.join(f.modules,'unsupported-fifo')]);rejected(()=>snapshotInstalledArtifactInputs(f.web));
});

test('finite file, byte, entry, depth and per-file limits fail before reading unbounded input',t=>{
  const f=fixture(t);f.file('pkg/a.js','aaa');f.file('pkg/b.js','bbb');
  for(const limits of [{maxFiles:1},{maxBytes:5},{maxEntries:2},{maxDepth:1},{maxFileBytes:2}])
    rejected(()=>snapshotInstalledArtifactInputs(f.web,limits));
  rejected(()=>snapshotInstalledArtifactInputs(f.web,{maxFiles:INSTALLED_ARTIFACT_INPUT_LIMITS.maxFiles+1}));
  const large=f.file('huge-file');fs.truncateSync(large,INSTALLED_ARTIFACT_INPUT_LIMITS.maxFileBytes+1);
  rejected(()=>snapshotInstalledArtifactInputs(f.web));
});

test('noncanonical file names cannot enter or escape the content manifest',t=>{
  for(const name of ['control\nname','back\\slash']){
    const f=fixture(t);f.file(name);rejected(()=>snapshotInstalledArtifactInputs(f.web));
  }
});

test('modified bytes, identical-byte source replacement and unrecorded additions after selection are rejected',t=>{
  for(const change of ['bytes','replacement','addition']){
    const f=fixture(t),file=f.file('pkg/file.js','selected bytes'),snapshot=snapshotInstalledArtifactInputs(f.web);
    if(change==='bytes')fs.writeFileSync(file,'changed bytes!');
    else if(change==='replacement'){fs.rmSync(file);fs.writeFileSync(file,'selected bytes');}
    else f.file('pkg/unrecorded.js');
    rejected(()=>stageInstalledArtifactInputs(f.web,f.target,snapshot));
    assert.equal(fs.existsSync(path.join(f.target,'node_modules')),false);
  }
});

test('symlink retargeting to an equal-byte file still changes the selected original inputs',t=>{
  const f=fixture(t);f.file('pkg/a.js','equal');f.file('pkg/b.js','equal');const link=path.join(f.modules,'tool');fs.symlinkSync('pkg/a.js',link);
  const snapshot=snapshotInstalledArtifactInputs(f.web);fs.rmSync(link);fs.symlinkSync('pkg/b.js',link);
  rejected(()=>stageInstalledArtifactInputs(f.web,f.target,snapshot));
});

test('forged paths, aggregate hashes, counts and link metadata cannot bypass snapshot validation',t=>{
  const f=fixture(t);f.file('pkg/file.js');fs.symlinkSync('pkg/file.js',path.join(f.modules,'tool'));
  const selected=snapshotInstalledArtifactInputs(f.web);
  for(const mutate of [value=>{value.entries[0].path='../escape';},value=>{value.sha256='0'.repeat(64);},
    value=>{value.fileCount++;},value=>{value.entries.find(entry=>entry.kind==='symlink').targetSha256='0'.repeat(64);}]){
    const snapshot=structuredClone(selected);mutate(snapshot);rejected(()=>stageInstalledArtifactInputs(f.web,f.target,snapshot));
  }
});

test('a dependency destination already linked to the original or nested in the selected tree is rejected',t=>{
  const f=fixture(t);f.file('pkg/file.js');const selected=snapshotInstalledArtifactInputs(f.web);
  fs.symlinkSync(f.modules,path.join(f.target,'node_modules'),'dir');rejected(()=>stageInstalledArtifactInputs(f.web,f.target,selected));
  rejected(()=>stageInstalledArtifactInputs(f.web,f.web,selected));
  const nested=path.join(f.modules,'pkg');rejected(()=>stageInstalledArtifactInputs(f.web,nested,selected));
});

test('corrupted copied bytes are found by the independent staged content rehash',t=>{
  const f=fixture(t);f.file('pkg/file.js','selected bytes');const selected=snapshotInstalledArtifactInputs(f.web);
  const original=fs.writeSync;let changed=false;
  fs.writeSync=function(fd,buffer,...rest){if(!changed){changed=true;buffer[0]^=1;}return original.call(this,fd,buffer,...rest);};
  try{rejected(()=>stageInstalledArtifactInputs(f.web,f.target,selected));}finally{fs.writeSync=original;}
  assert.equal(changed,true);assert.equal(fs.readFileSync(path.join(f.modules,'pkg/file.js'),'utf8'),'selected bytes');
});

test('an original file mutated after it was copied is rejected by the final source identity sweep',t=>{
  const f=fixture(t),earlier=f.file('a.js','first selected bytes');f.file('z.js','last selected bytes');
  const selected=snapshotInstalledArtifactInputs(f.web),original=fs.writeSync;let calls=0;
  fs.writeSync=function(...args){const result=original.apply(this,args);if(++calls===2)fs.writeFileSync(earlier,'mutated after copying');return result;};
  try{rejected(()=>stageInstalledArtifactInputs(f.web,f.target,selected));}finally{fs.writeSync=original;}
  assert.ok(calls>=2);
});
