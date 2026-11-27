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
