'use strict';
// Only the trusted server worker may write this directory. It must live on
// persistent storage, not /tmp or a disposable container layer.
const fs=require('node:fs');
const path=require('node:path');
const {randomUUID}=require('node:crypto');
const {validateResult}=require('./online-stats');
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
function syncDirectory(dir){
 const fd=fs.openSync(dir,'r');
 try{fs.fsyncSync(fd);}finally{fs.closeSync(fd);}
}
function createJournal(dir){
 if(!path.isAbsolute(dir))throw Error('Persistent absolute result journal required');
 fs.mkdirSync(dir,{recursive:true,mode:0o700});
 const info=fs.lstatSync(dir);
 if(!info.isDirectory()||info.isSymbolicLink()||(info.mode&0o077)!==0)throw Error('Result journal must be private');
 function check(entry){
  if(!entry||entry.schema!==1||!uuid.test(entry.roomId)||!['solo','duo','squad'].includes(entry.mode))throw Error('Invalid journal envelope');
  validateResult(entry.result,entry.roomId,entry.accounts,entry.mode);
 }
 function read(file){
  const info=fs.lstatSync(file);
  if(!info.isFile()||info.isSymbolicLink()||info.size>32768)throw Error('Invalid journal entry');
  const entry=JSON.parse(fs.readFileSync(file,'utf8'));check(entry);
  if(path.basename(file)!==entry.roomId+'.json')throw Error('Mismatched journal filename');
  return entry;
 }
 function stage(entry){
  check(entry);
  const final=path.join(dir,entry.roomId+'.json');
  const data=JSON.stringify(entry)+'\n';
  if(Buffer.byteLength(data)>32768)throw Error('Journal entry too large');
  const temporary=path.join(dir,'.'+randomUUID()+'.tmp');
  const fd=fs.openSync(temporary,'wx',0o600);
  try{fs.writeFileSync(fd,data);fs.fsyncSync(fd);}finally{fs.closeSync(fd);}
  try{
   // No clobber: a different result for an already recorded match fails.
   try{fs.linkSync(temporary,final);}catch(error){
    if(error.code!=='EEXIST')throw error;
    if(JSON.stringify(read(final))!==JSON.stringify(entry))throw Error('Conflicting match result');
   }
   syncDirectory(dir);
  }finally{fs.unlinkSync(temporary);syncDirectory(dir);}
  return final;
 }
 async function deliver(file,persist){
  const entry=read(file);
  const result=await persist(entry);
  if(!result||typeof result.duplicate!=='boolean')throw Error('No commit confirmation');
  // If the process dies between Firestore commit and unlink, the existing
  // transactional receipt makes the next replay a harmless duplicate.
  fs.unlinkSync(file);syncDirectory(dir);
  return result;
 }
 async function recover(persist){
  let count=0;
  for(const name of fs.readdirSync(dir).filter(n=>n.endsWith('.json')).sort()){
   await deliver(path.join(dir,name),persist);count++;
  }
  return count;
 }
 return {stage,deliver,recover};
}
module.exports={createJournal};
