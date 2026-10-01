/** Byte attribution and independent staging of the existing installed tree.
 * Only filesystem metadata and SHA256 digests enter the manifest. No package
 * code is executed, dependencies installed, or network request made.
 */
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';

export const INSTALLED_ARTIFACT_INPUT_LIMITS = Object.freeze({
  maxFiles:100000,maxBytes:2*1024**3,maxFileBytes:256*1024**2,
  maxEntries:150000,maxDepth:64,maxPathBytes:4096,maxLinkHops:64,
});
const hash=value=>createHash('sha256').update(value).digest('hex');
const fail=code=>{const error=new Error(code);error.code=code;throw error;};
const need=(value,code)=>{if(!value)fail(code);};
const identity=stat=>Object.fromEntries(['dev','ino','mode','size','mtimeNs','ctimeNs','birthtimeNs'].map(key=>[key,String(stat[key])]));
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
const mode=stat=>Number(stat.mode&0o7777n);
const full=(root,relative)=>path.join(root,...relative.split('/'));
function limitsOf(overrides={}){
  need(overrides&&typeof overrides==='object'&&!Array.isArray(overrides),'artifact_installed_input_limit');
  need(Object.keys(overrides).every(key=>Object.hasOwn(INSTALLED_ARTIFACT_INPUT_LIMITS,key)),'artifact_installed_input_limit');
  const limits={...INSTALLED_ARTIFACT_INPUT_LIMITS,...overrides};
  for(const key of Object.keys(limits))need(Number.isSafeInteger(limits[key])&&limits[key]>0&&limits[key]<=INSTALLED_ARTIFACT_INPUT_LIMITS[key],'artifact_installed_input_limit');
  return limits;
}
function relativePath(value,limits){
  need(typeof value==='string'&&value.length>0&&!/[\\\x00-\x1f\x7f]/.test(value)&&
    Buffer.byteLength(value)<=limits.maxPathBytes&&!value.startsWith('/')&&
    value.split('/').every(part=>part&&part!=='.'&&part!=='..'),'artifact_installed_input_path_rejected');
  need(value.split('/').length<=limits.maxDepth,'artifact_installed_input_limit');
  return value;
}
function sourceRoot(web){
  const root=path.join(fs.realpathSync(path.resolve(web)),'node_modules');
  need(fs.lstatSync(root).isDirectory()&&fs.realpathSync(root)===root,'artifact_installed_input_type_rejected');
  return root;
}
function guarded(action){
  try{return action();}catch(error){
    if(typeof error?.code==='string'&&error.code.startsWith('artifact_installed_input_'))throw error;
    fail('artifact_installed_input_io_rejected');
  }
}
function fileBytes(file,expected,consume){
  need(typeof fs.constants.O_NOFOLLOW==='number','artifact_installed_input_type_rejected');
  const fd=fs.openSync(file,fs.constants.O_RDONLY|fs.constants.O_NOFOLLOW);
  try{
    const before=fs.fstatSync(fd,{bigint:true});
    need(before.isFile()&&same(identity(before),expected.identity),'artifact_installed_input_changed');
    const digest=createHash('sha256'),buffer=Buffer.allocUnsafe(Math.max(1,Math.min(expected.bytes,1024*1024)));let offset=0;
    for(;;){
      const size=fs.readSync(fd,buffer,0,buffer.length,offset);if(!size)break;
      offset+=size;need(offset<=expected.bytes,'artifact_installed_input_changed');
      digest.update(buffer.subarray(0,size));if(consume)consume(buffer,size);
    }
    need(offset===expected.bytes&&same(identity(fs.fstatSync(fd,{bigint:true})),expected.identity)&&
      same(identity(fs.lstatSync(file,{bigint:true})),expected.identity),'artifact_installed_input_changed');
    return digest.digest('hex');
  }finally{fs.closeSync(fd);}
}
function collect(root,limits,readBytes){
  const rootStat=fs.lstatSync(root,{bigint:true});
  need(rootStat.isDirectory()&&fs.realpathSync(root)===root,'artifact_installed_input_type_rejected');
  const entries=[];let fileCount=0,totalBytes=0,directoryCount=0,symlinkCount=0;
  const visit=parent=>{
    for(const name of fs.readdirSync(parent?full(root,parent):root).sort()){
      const relative=relativePath(parent?parent+'/'+name:name,limits),file=full(root,relative);
      const stat=fs.lstatSync(file,{bigint:true});
      const item={path:relative,kind:null,mode:mode(stat),identity:identity(stat)};
      need(entries.length<limits.maxEntries,'artifact_installed_input_limit');
      if(stat.isSymbolicLink()){
        item.kind='symlink';item.sourceLink=fs.readlinkSync(file);item.bytes=Buffer.byteLength(item.sourceLink);symlinkCount++;
      }else if(stat.isDirectory()){
        item.kind='directory';item.bytes=0;directoryCount++;
      }else{
        need(stat.isFile(),'artifact_installed_input_type_rejected');
        item.kind='file';item.bytes=Number(stat.size);fileCount++;totalBytes+=item.bytes;
        need(fileCount<=limits.maxFiles&&Number.isSafeInteger(item.bytes)&&item.bytes<=limits.maxFileBytes&&totalBytes<=limits.maxBytes,'artifact_installed_input_limit');
        if(readBytes)item.sha256=fileBytes(file,item);
      }
      entries.push(item);if(item.kind==='directory')visit(relative);
    }
  };
  visit('');entries.sort((a,b)=>a.path<b.path?-1:a.path>b.path?1:0);
  return {rootIdentity:identity(rootStat),rootMode:mode(rootStat),entries,fileCount,directoryCount,symlinkCount,totalBytes};
}
function binding(root,value){
  return hash(JSON.stringify({sourceRoot:root,rootIdentity:value.rootIdentity,
    entries:value.entries.map(item=>({path:item.path,identity:item.identity,...(item.kind==='symlink'?{sourceLink:item.sourceLink}:{})}))}));
}
function portable(item){
  const value={path:item.path,kind:item.kind,mode:item.mode,bytes:item.kind==='symlink'?Buffer.byteLength(item.link):item.bytes};
  if(item.kind==='file')value.sha256=item.sha256;
  if(item.kind==='symlink')Object.assign(value,{link:item.link,target:item.target,targetKind:item.targetKind,targetSha256:item.targetSha256});
  return value;
}
function contentHash(value){return hash(JSON.stringify({rootMode:value.rootMode,entries:value.entries.map(portable)}));}
function deriveLinks(root,entries,limits,checkFilesystem){
  const byPath=new Map(entries.map(item=>[item.path,item]));
  function segments(link){
    need(typeof link==='string'&&link.length>0&&!/[\\\x00-\x1f\x7f]/.test(link)&&Buffer.byteLength(link)<=limits.maxPathBytes,'artifact_installed_input_link_rejected');
    if(path.isAbsolute(link)){
      need(link.startsWith(root+path.sep),'artifact_installed_input_link_rejected');
      const inside=link.slice(root.length+1).split('/');
      need(inside.every(part=>part&&part!=='.'&&part!=='..'),'artifact_installed_input_link_rejected');
      return {absolute:true,parts:inside};
    }
    return {absolute:false,parts:link.split('/')};
  }
  function resolve(item){
    let stack=item.path.split('/').slice(0,-1),queue=[],hops=0;
    const first=segments(item.sourceLink);if(first.absolute)stack=[];queue.push(...first.parts);
    while(queue.length){
      const part=queue.shift();if(!part||part==='.')continue;
      if(part==='..'){need(stack.length>0,'artifact_installed_input_link_rejected');stack.pop();continue;}
      const candidate=stack.concat(part).join('/'),found=byPath.get(candidate);
      need(found,'artifact_installed_input_link_rejected');
      if(found.kind==='symlink'){
        need(++hops<=limits.maxLinkHops,'artifact_installed_input_link_rejected');
        const next=segments(found.sourceLink);if(next.absolute)stack=[];queue.unshift(...next.parts);
      }else{
        need(found.kind==='directory'||queue.length===0,'artifact_installed_input_link_rejected');stack.push(part);
      }
    }
    const target=stack.join('/'),found=target?byPath.get(target):{kind:'directory'};
    need(found&&(found.kind==='file'||found.kind==='directory'),'artifact_installed_input_link_rejected');
    if(checkFilesystem)need(fs.realpathSync(full(root,item.path))===(target?full(root,target):root),'artifact_installed_input_link_rejected');
    return {target,targetKind:found.kind};
  }
  for(const item of entries.filter(item=>item.kind==='symlink')){
    const first=segments(item.sourceLink),parent=path.posix.dirname(item.path);
    item.link=first.absolute?path.posix.relative(parent,first.parts.join('/'))||'.':item.sourceLink;
    Object.assign(item,resolve(item));
  }
  // Directory target hashes include every actual subtree file and link record;
  // they omit derived target hashes to avoid recursive directory-link digests.
  const base=entries.map(item=>{const value=portable(item);delete value.targetSha256;return value;});
  const directoryHashes=new Map();
  for(const item of entries.filter(item=>item.kind==='symlink')){
    if(item.targetKind==='file')item.targetSha256=byPath.get(item.target).sha256;
    else{
      if(!directoryHashes.has(item.target))directoryHashes.set(item.target,hash(JSON.stringify(base.filter(entry=>!item.target||entry.path===item.target||entry.path.startsWith(item.target+'/')))));
      item.targetSha256=directoryHashes.get(item.target);
    }
  }
}
function assertOriginal(root,snapshot){
  need(fs.realpathSync(root)===root,'artifact_installed_input_changed');
  const current=collect(root,snapshot.limits,false);
  need(binding(root,current)===snapshot.sourceBindingSha256,'artifact_installed_input_changed');
}
function validateSnapshot(root,snapshot){
  need(snapshot?.schemaVersion===1&&snapshot.sourceRoot===root&&Array.isArray(snapshot.entries),'artifact_installed_input_snapshot_rejected');
  const limits=limitsOf(snapshot.limits),byPath=new Map();let files=0,bytes=0,dirs=0,links=0;
  need(snapshot.entries.length<=limits.maxEntries&&Number.isInteger(snapshot.rootMode)&&snapshot.rootMode>=0&&snapshot.rootMode<=0o7777,'artifact_installed_input_snapshot_rejected');
  let previous='';
  for(const item of snapshot.entries){
    relativePath(item.path,limits);need(item.path>previous,'artifact_installed_input_snapshot_rejected');previous=item.path;
    need(['file','directory','symlink'].includes(item.kind)&&Number.isInteger(item.mode)&&item.mode>=0&&item.mode<=0o7777&&
      Number.isSafeInteger(item.bytes)&&item.bytes>=0&&item.identity&&Object.keys(identity({})).every(key=>typeof item.identity[key]==='string'),'artifact_installed_input_snapshot_rejected');
    const parent=path.posix.dirname(item.path);need(parent==='.'||byPath.get(parent)?.kind==='directory','artifact_installed_input_snapshot_rejected');byPath.set(item.path,item);
    if(item.kind==='file'){files++;bytes+=item.bytes;need(item.bytes<=limits.maxFileBytes&&/^[0-9a-f]{64}$/.test(item.sha256),'artifact_installed_input_snapshot_rejected');}
    else if(item.kind==='directory'){dirs++;need(item.bytes===0,'artifact_installed_input_snapshot_rejected');}
    else{links++;need(typeof item.sourceLink==='string'&&item.bytes===Buffer.byteLength(item.sourceLink),'artifact_installed_input_snapshot_rejected');}
  }
  need(files<=limits.maxFiles&&bytes<=limits.maxBytes&&files===snapshot.fileCount&&bytes===snapshot.totalBytes&&dirs===snapshot.directoryCount&&links===snapshot.symlinkCount,'artifact_installed_input_snapshot_rejected');
  const checked=snapshot.entries.map(item=>({...item}));deriveLinks(root,checked,limits,false);
  need(same(checked.map(portable),snapshot.entries.map(portable))&&contentHash(snapshot)===snapshot.sha256&&
    binding(root,snapshot)===snapshot.sourceBindingSha256,'artifact_installed_input_snapshot_rejected');
}

/** Synchronous manifest, suitable for an ignored JSON file. sha256 binds the
 * portable content tree; sourceBindingSha256 additionally binds source inode,
 * timestamps and original symlink text. Neither contains raw file content.
 */
export function snapshotInstalledArtifactInputs(web,optionalLimits={}){
  return guarded(()=>{
    const root=sourceRoot(web),limits=limitsOf(optionalLimits),value=collect(root,limits,true);
    deriveLinks(root,value.entries,limits,true);
    const snapshot={schemaVersion:1,sourceRoot:root,limits,...value};
    snapshot.sha256=contentHash(snapshot);snapshot.sourceBindingSha256=binding(root,snapshot);
    assertOriginal(root,snapshot);return snapshot;
  });
}

/** Creates targetWeb/node_modules exclusively. It returns only a finite proof
 * summary. Partial failed staging remains in the caller's disposable directory;
 * callers must execute no converter unless this function returns verified=true.
 */
export function stageInstalledArtifactInputs(web,targetWeb,snapshot){
  return guarded(()=>{
    const root=sourceRoot(web);validateSnapshot(root,snapshot);assertOriginal(root,snapshot);
    need(fs.lstatSync(path.resolve(targetWeb)).isDirectory(),'artifact_installed_input_destination_rejected');
    const target=fs.realpathSync(path.resolve(targetWeb)),destination=path.join(target,'node_modules');
    for(const [a,b] of [[root,destination],[destination,root]]){
      const relative=path.relative(a,b);need(relative&&relative!=='..'&&(relative.startsWith('..'+path.sep)||path.isAbsolute(relative)),'artifact_installed_input_destination_rejected');
    }
    need(!fs.existsSync(destination),'artifact_installed_input_destination_rejected');fs.mkdirSync(destination,{mode:0o700});
    for(const item of snapshot.entries.filter(item=>item.kind==='directory'))fs.mkdirSync(full(destination,item.path),{mode:0o700});
    for(const item of snapshot.entries.filter(item=>item.kind==='file')){
      const output=full(destination,item.path),fd=fs.openSync(output,fs.constants.O_CREAT|fs.constants.O_EXCL|fs.constants.O_WRONLY,0o600);
      try{
        const observed=fileBytes(full(root,item.path),item,(buffer,size)=>{
          let offset=0;while(offset<size){const written=fs.writeSync(fd,buffer,offset,size-offset);need(written>0,'artifact_installed_input_io_rejected');offset+=written;}
        });
        need(observed===item.sha256,'artifact_installed_input_changed');
        fs.fchmodSync(fd,item.mode);
        const staged=fs.fstatSync(fd,{bigint:true});need(String(staged.ino)!==item.identity.ino||String(staged.dev)!==item.identity.dev,'artifact_installed_input_destination_rejected');
      }finally{fs.closeSync(fd);}
    }
    for(const item of snapshot.entries.filter(item=>item.kind==='symlink'))fs.symlinkSync(item.link,full(destination,item.path),item.targetKind==='directory'?'dir':'file');
    for(const item of snapshot.entries.filter(item=>item.kind==='directory').reverse())fs.chmodSync(full(destination,item.path),item.mode);
    fs.chmodSync(destination,snapshot.rootMode);
    const staged=snapshotInstalledArtifactInputs(target,snapshot.limits);
    need(staged.sha256===snapshot.sha256&&same(staged.entries.map(portable),snapshot.entries.map(portable)),'artifact_installed_input_changed');
    assertOriginal(root,snapshot);
    return {schemaVersion:1,verified:true,sha256:snapshot.sha256,sourceBindingSha256:snapshot.sourceBindingSha256,
      stagedBindingSha256:staged.sourceBindingSha256,fileCount:staged.fileCount,directoryCount:staged.directoryCount,
      symlinkCount:staged.symlinkCount,totalBytes:staged.totalBytes,sourceRechecked:true,
      copiedRegularFiles:true,linksToOriginalDependencies:0,dependencyInstalls:0,networkRequests:0};
  });
}
