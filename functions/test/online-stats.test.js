'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {persistRoomResult,getOnlineStats,validateResult,subFor}=require('../src/online-stats');
const uid='account-a',sub=subFor(uid),roomId='room-a';
function fake(){
 const data=new Map([['online_rooms/'+roomId,{status:'sealed',mode:'solo',accounts:[sub]}],['player_identities/'+uid,{number:42}]]);
 const ref=path=>({path,get:async()=>snap(path)});
 const snap=path=>({exists:data.has(path),data:()=>structuredClone(data.get(path))});
 return {data,collection:name=>({doc:id=>ref(name+'/'+id)}),async runTransaction(fn){
   const writes=[];const tx={get:async r=>snap(r.path),set:(r,v)=>writes.push([r.path,v]),create:(r,v)=>{assert(!data.has(r.path));writes.push([r.path,v]);},update:(r,v)=>writes.push([r.path,{...data.get(r.path),...v}])};
   const result=await fn(tx);for(const [path,v] of writes)data.set(path,structuredClone(v));return result;
 }};
}
const result={room:roomId,completed:true,seconds:480,records:[{sub,slot:0,kills:7,hits:19,won:true,abandoned:false}]};
test('one authoritative match writes permanent stats and cannot be counted twice',async()=>{
 const db=fake(),args={firestore:db,roomId,result,serverTimestamp:()=>1};
 assert.deepEqual(await persistRoomResult(args),{duplicate:false});
 assert.deepEqual(await persistRoomResult(args),{duplicate:true});
 const stats=await getOnlineStats({firestore:db,request:{auth:{uid},app:{}},createError:(c,m)=>Error(m)});
 assert.deepEqual(stats,{schema:1,played:1,wins:1,kills:7,hits:19,abandoned:0,seconds:480,ranked:false});
});
test('forged identity, impossible outcomes, or duplicate roster rejected before writes',async()=>{
 for(const edit of [r=>r.records[0].sub='ab'.repeat(32),r=>r.records[0].kills=50,r=>r.completed=false,r=>r.records.push(r.records[0])]){
  const db=fake(),bad=structuredClone(result);edit(bad);
  await assert.rejects(persistRoomResult({firestore:db,roomId,result:bad,serverTimestamp:()=>1}));
  assert.equal(db.data.has('online_match_receipts/'+roomId),false);
 }
});
test('abandoned match cannot be credited with a victory',()=>{
 const bad=structuredClone(result);bad.records[0].abandoned=true;
 assert.throws(()=>validateResult(bad,roomId,[sub],'solo'));
});
test('client cannot select another account',async()=>{
 const db=fake();
 await assert.rejects(getOnlineStats({firestore:db,request:{auth:{uid},app:{},data:{uid:'other'}},createError:(c,m)=>Error(m)}));
 await assert.rejects(getOnlineStats({firestore:db,request:{data:{}},createError:(c,m)=>Error(m)}));
});
