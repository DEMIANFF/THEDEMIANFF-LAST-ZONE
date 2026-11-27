'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createServer}=require('node:http');
const {createExternalHandler}=require('../src/external-api');
test('external callable enforces both tokens, exact app and server-owned UID',async t=>{
  let reads=0;
  const firestore={runTransaction:async fn=>fn({get:async ref=>{reads++;assert.equal(ref.id,'real-user');return {exists:true,get:()=>17};}}),
    collection:()=>({doc:id=>({id}),orderBy:()=>({limit:()=>({})})})};
  const handler=createExternalHandler({firestore,appId:'preview-app',
    verifyAuth:async token=>{assert.equal(token,'auth.good');return {uid:'real-user'};},
    verifyApp:async token=>({appId:token==='app.good'?'preview-app':'other-app'}),
    serverTimestamp:()=>0});
  const server=createServer(handler);await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  t.after(()=>new Promise(resolve=>server.close(resolve)));
  const base='http://127.0.0.1:'+server.address().port;
  const call=(name,data,headers={})=>fetch(base+'/api/'+name,{method:'POST',
    headers:{'content-type':'application/json',...headers},body:JSON.stringify(data)});
  const headers={authorization:'Bearer auth.good','x-firebase-appcheck':'app.good'};
  assert.equal((await fetch(base+'/healthz')).status,200);
  assert.equal((await call('ensurePlayerIdentity',{data:null})).status,401);
  assert.equal((await call('ensurePlayerIdentity',{data:null},{authorization:'Bearer auth.good'})).status,401);
  assert.equal((await call('ensurePlayerIdentity',{data:null},{...headers,'x-firebase-appcheck':'app.bad'})).status,403);
  assert.equal((await call('ensurePlayerIdentity',{data:{uid:'victim'}},headers)).status,400);
  assert.equal((await call('ensurePlayerIdentity',{uid:'victim'},headers)).status,400);
  assert.equal((await call('constructor',{data:null},headers)).status,404);
  assert.equal(reads,0);
  const response=await call('ensurePlayerIdentity',{data:null},headers);
  assert.equal(response.status,200);
  assert.deepEqual(await response.json(),{result:{number:17}});
  assert.equal(reads,1);
  const denied=await call('requestOnlineMatch',{data:{mode:'solo',protocol:31}},headers);
  assert.equal(denied.status,503);
  assert.equal((await denied.json()).error.status,'UNAVAILABLE');
});
