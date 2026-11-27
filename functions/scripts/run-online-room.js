'use strict';
// Operator-controlled Linux service only. Firebase credentials, ticket
// signing key and TLS private key are never part of the Android APK.
const {initializeApp}=require('firebase-admin/app');
const {getFirestore,FieldValue}=require('firebase-admin/firestore');
const {persistRoomResult}=require('../src/online-stats');
const {createJournal}=require('../src/online-result-journal');
const {randomUUID}=require('node:crypto');
const {spawn}=require('node:child_process');
const {createInterface}=require('node:readline');
const {resolve,join}=require('node:path');
const {PROTOCOL,validEndpoint}=require('../src/online-matchmaking');
const endpoint=process.env.AURORA_PUBLIC_ENDPOINT;
const mode=process.env.AURORA_MODE||'solo';
if(!validEndpoint(endpoint)||!['solo','duo','squad'].includes(mode)||
   !/^[a-f0-9]{64}$/i.test(process.env.AURORA_MATCH_SIGNING_KEY||'')||
   !process.env.AURORA_TLS_CERT||!process.env.AURORA_TLS_KEY)throw Error('Missing public room configuration');
const port=Number(process.env.AURORA_ROOM_PORT||24621);
if(!Number.isInteger(port)||port<1024||port>65535||Number(new URL(endpoint).port||443)!==port)throw Error('Public endpoint and TCP room port must match');
const state=process.env.AURORA_RESULT_SPOOL||(process.env.XDG_DATA_HOME?join(process.env.XDG_DATA_HOME,'results-'+port):'');
const journal=createJournal(state);
initializeApp();
const db=getFirestore();
const persist=async entry=>{
 for(let attempt=0;attempt<5;attempt++){
  try{
   return await persistRoomResult({firestore:db,roomId:entry.roomId,result:entry.result,serverTimestamp:()=>FieldValue.serverTimestamp()});
  }catch(err){
   if(attempt===4)throw err;
   await new Promise(resolve=>setTimeout(resolve,500*2**attempt));
  }
 }
};
async function main(){
 // Never advertise a fresh room while a durable receipt is still unsaved.
 const recovered=await journal.recover(persist);
 console.log('AURORA_RESULT_JOURNAL_RECOVERED count='+recovered);
 const id=randomUUID(),room=db.collection('online_rooms').doc(id);
 const env={...process.env,AURORA_INTERNET_SERVER:'1',AURORA_ROOM_ID:id,AURORA_ROOM_PORT:String(port),AURORA_TEAM_SIZE:String({solo:1,duo:2,squad:4}[mode])};
 delete env.AURORA_LAN_BIND;
 delete env.AURORA_INTERNET_QA;
 const child=spawn(process.env.GODOT_BIN||'godot',['--headless','--path',resolve(__dirname,'../../native-godot'),'--script','res://scripts/network/dedicated_server.gd'],{env,stdio:['ignore','pipe','inherit']});
 let status='starting',timer,chain=Promise.resolve(),closing=false,accounts=null,pendingResult=null,saved=false,failed=false;
 function fail(){
  if(failed)return;
  failed=true;clearInterval(timer);
  console.error('AURORA_ROOM_WORKER_FAILED; journal retained if staged');
  process.exitCode=1;child.kill('SIGTERM');
 }
 function queue(fn){
  chain=chain.then(fn);
  chain.catch(fail);
  return chain;
 }
 const update=value=>queue(()=>room.set(value,{merge:true}));
 createInterface({input:child.stdout}).on('line',line=>{
  if(failed||closing)return;
  if(line.startsWith('AURORA_ONLINE READY TLS Internet')&&status==='starting'){
   status='open';
   update({status,endpoint,mode,protocol:PROTOCOL,capacity:4,heartbeat:Math.floor(Date.now()/1000),reservations:{}});
   timer=setInterval(()=>{if(status==='open'&&!failed)update({heartbeat:Math.floor(Date.now()/1000)});},4000);
  }else if(line.startsWith('AURORA_ROOM_ROSTER ')){
   try{
    const roster=JSON.parse(line.slice('AURORA_ROOM_ROSTER '.length));
    if(roster.room!==id||!Array.isArray(roster.accounts)||roster.accounts.length<1||roster.accounts.length>4||
       roster.accounts.some(x=>typeof x!=='string'||!/^[a-f0-9]{64}$/.test(x))||new Set(roster.accounts).size!==roster.accounts.length)throw Error('invalid roster');
    accounts=roster.accounts;
   }catch{fail();}
   return;
  }else if(line.startsWith('V75250_SEALED')&&status==='open'){
   if(!accounts){fail();return;}
   status='sealed';clearInterval(timer);
   update({status,accounts,heartbeat:Math.floor(Date.now()/1000)});
  }else if(line.startsWith('AURORA_ROOM_RESULT ')){
   if(status!=='sealed'||pendingResult)return;
   try{
    const result=JSON.parse(line.slice('AURORA_ROOM_RESULT '.length));
    pendingResult=journal.stage({schema:1,roomId:id,mode,accounts,result});
    queue(async()=>{
     await journal.deliver(pendingResult,persist);
     saved=true;status='finished';
     console.log('AURORA_ONLINE_RESULT_SAVED');
    });
   }catch{fail();}
   return;
  }
  // Do not forward the private account/result envelopes into public logs.
  console.log(line);
 });
 async function close(code){
  if(closing)return;
  closing=true;clearInterval(timer);
  try{
   await chain;
   if(!failed&&!pendingResult&&!saved&&status!=='starting'){
    await room.set({status:'closed',heartbeat:Math.floor(Date.now()/1000)},{merge:true});
   }
  }catch{failed=true;}
  // Never overwrite a finished receipt or close a sealed room with an
  // unsaved journal. Recovery must be able to commit it on restart.
  process.exitCode=failed?1:(code||0);
 }
 child.on('close',code=>{void close(code);});
 child.on('error',()=>{void close(1);});
 for(const sig of ['SIGTERM','SIGINT'])process.on(sig,()=>child.kill(sig));
}
main().catch(()=>{console.error('AURORA_RESULT_JOURNAL_RECOVERY_FAILED');process.exitCode=1;});
