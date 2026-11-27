'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createJournal}=require('../src/online-result-journal');
const id='12345678-1234-1234-1234-123456789abc',sub='ab'.repeat(32);
const entry={schema:1,roomId:id,mode:'solo',accounts:[sub],result:{room:id,completed:true,seconds:300,records:[{sub,slot:0,kills:2,hits:8,won:true,abandoned:false}]}};
function fixture(t){const dir=fs.mkdtempSync(path.join(os.tmpdir(),'aurora-results-'));t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));return dir;}
test('failed Firestore commit leaves a durable private journal recoverable by a new worker',async t=>{
 const dir=fixture(t),first=createJournal(dir),file=first.stage(entry);
 assert.equal(fs.statSync(file).mode&0o777,0o600);
 await assert.rejects(first.deliver(file,async()=>{throw Error('outage');}));
 assert(fs.existsSync(file));
 const restarted=createJournal(dir);
 let committed=0;
 assert.equal(await restarted.recover(async saved=>{assert.deepEqual(saved,entry);committed++;return {duplicate:false};}),1);
 assert.equal(committed,1);assert(!fs.existsSync(file));
 assert.equal(await restarted.recover(async()=>{throw Error('unexpected commit');}),0);
});
test('replay after commit but before journal removal confirms existing receipt without counting again',async t=>{
 const dir=fixture(t),journal=createJournal(dir);
 const file=journal.stage(entry);
 let matches=1; // original Firestore transaction was committed before crash
 assert.equal(await createJournal(dir).recover(async saved=>{assert.equal(saved.roomId,id);return {duplicate:true};}),1);
 assert.equal(matches,1);assert(!fs.existsSync(file));
});
test('conflicting result and unknown account cannot replace a staged record',t=>{
 const journal=createJournal(fixture(t)),file=journal.stage(entry);
 assert.equal(journal.stage(entry),file);
 const other=structuredClone(entry);other.result.records[0].kills=3;
 assert.throws(()=>journal.stage(other),/Conflicting/);
 other.result.records[0].sub='cd'.repeat(32);
 assert.throws(()=>journal.stage(other));
 assert.deepEqual(JSON.parse(fs.readFileSync(file)),entry);
});
test('malformed or missing commit confirmation never deletes a record',async t=>{
 const journal=createJournal(fixture(t)),file=journal.stage(entry);
 await assert.rejects(journal.deliver(file,async()=>undefined),/confirmation/);
 assert(fs.existsSync(file));
});
