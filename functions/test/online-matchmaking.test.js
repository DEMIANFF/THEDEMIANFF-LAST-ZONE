'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const {issueTicket,validEndpoint,requestOnlineMatch,PROTOCOL}=require('../src/online-matchmaking');
test('signed room ticket uses exact bytes and no raw Firebase UID',()=>{
 const key='ab'.repeat(32),sub='cd'.repeat(32),nonce='ef'.repeat(18);
 const [payload,sig]=issueTicket({room:'room-instance-123456',sub,nonce,exp:1000,signingKey:key}).split('.');
 assert.equal(sig,crypto.createHmac('sha256',Buffer.from(key,'hex')).update(payload).digest('hex'));
 assert.deepEqual(JSON.parse(Buffer.from(payload,'base64')),{v:PROTOCOL,room:'room-instance-123456',sub,nonce,exp:1000});
 assert.throws(()=>issueTicket({room:'x',sub,nonce,exp:1000,signingKey:'bad'}));
});
test('public TLS domain only',()=>{
 assert.equal(validEndpoint('wss://br.example.com:24621'),true);
 for(const v of ['ws://br.example.com','wss://127.0.0.1','wss://192.168.1.1','wss://host.local','wss://user:password@br.example.com','wss://br.example.com?a=b'])assert.equal(validEndpoint(v),false);
});
test('unauthenticated or incompatible requests cannot access room registry',async()=>{
 const err=(code,message)=>Object.assign(new Error(message),{code});
 const firestore={collection(){throw new Error('unexpected database access')}};
 await assert.rejects(requestOnlineMatch({firestore,request:{data:{mode:'solo',protocol:PROTOCOL}},signingKey:'ab'.repeat(32),createError:err}),{code:'unauthenticated'});
 await assert.rejects(requestOnlineMatch({firestore,request:{auth:{uid:'a'},app:{},data:{mode:'ranked',protocol:PROTOCOL}},signingKey:'ab'.repeat(32),createError:err}),{code:'failed-precondition'});
});

function fixture() {
  const rooms=new Map(), assignments=new Map(), identities=new Map();
  const collections={online_rooms:rooms,online_assignments:assignments,player_identities:identities};
  const ref=(name,id)=>({id,name,get:async()=>snapshot(name,id)});
  const snapshot=(name,id)=>({exists:collections[name].has(id),data:()=>structuredClone(collections[name].get(id))});
  const firestore={
    collection(name){return {doc:id=>ref(name,id),where:(field,op,value)=>({limit:n=>({get:async()=>({docs:[...rooms].filter(([,r])=>r[field]===value).slice(0,n).map(([id])=>({ref:ref(name,id)}))})})})};},
    async runTransaction(fn){
      const writes=[];
      const result=await fn({get:async r=>snapshot(r.name,r.id),update:(r,v)=>writes.push([r,{...collections[r.name].get(r.id),...v}]),set:(r,v)=>writes.push([r,v])});
      for(const [r,v] of writes)collections[r.name].set(r.id,structuredClone(v));
      return result;
    }
  };
  return {firestore,rooms,assignments,identities};
}
const validRoom=()=>({status:'open',mode:'solo',protocol:PROTOCOL,heartbeat:100,capacity:4,endpoint:'wss://br.example.com:24621',reservations:{}});
const error=(code,message)=>Object.assign(new Error(message),{code});
function reserve(f,uid,now=100){return requestOnlineMatch({firestore:f.firestore,request:{auth:{uid},app:{},data:{mode:'solo',protocol:PROTOCOL}},signingKey:'ab'.repeat(32),createError:error,now});}
test('reservation keeps account identity stable and caps actual available slots',async()=>{
 const f=fixture();f.rooms.set('real-room-instance-1',validRoom());
 for(let n=0;n<5;n++)f.identities.set('user'+n,{number:n+1});
 const first=await reserve(f,'user0'),again=await reserve(f,'user0');
 assert.equal(first.ticket,again.ticket);
 assert.equal(first.expires,145);
 for(let n=1;n<4;n++)await reserve(f,'user'+n);
 await assert.rejects(reserve(f,'user4'),{code:'unavailable'});
 assert.equal(Object.keys(f.rooms.get('real-room-instance-1').reservations).length,4);
});
test('stale rooms and accounts without permanent identity are rejected',async()=>{
 const f=fixture();f.rooms.set('real-room-instance-1',{...validRoom(),heartbeat:80});
 await assert.rejects(reserve(f,'user0'),{code:'failed-precondition'});
 f.identities.set('user0',{number:1});
 await assert.rejects(reserve(f,'user0'),{code:'unavailable'});
 assert.equal(f.assignments.size,0);
});
