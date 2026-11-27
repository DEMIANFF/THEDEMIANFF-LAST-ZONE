'use strict';
// Run only on an operator-controlled host with Application Default Credentials,
// a TLS certificate, DNS, and the same secret injected securely on the server.
const {initializeApp}=require('firebase-admin/app');
const {getFirestore,FieldValue}=require('firebase-admin/firestore');
const {persistRoomResult}=require('../src/online-stats');
const {randomUUID}=require('node:crypto');
const {spawn}=require('node:child_process');
const {createInterface}=require('node:readline');
const {resolve}=require('node:path');
const {PROTOCOL,validEndpoint}=require('../src/online-matchmaking');
const endpoint=process.env.AURORA_PUBLIC_ENDPOINT;
const mode=process.env.AURORA_MODE || 'solo';
if (!validEndpoint(endpoint) || !['solo','duo','squad'].includes(mode) ||
    !/^[a-f0-9]{64}$/i.test(process.env.AURORA_MATCH_SIGNING_KEY||'') ||
    !process.env.AURORA_TLS_CERT || !process.env.AURORA_TLS_KEY) throw Error('Missing public room configuration');
initializeApp();
const db=getFirestore();
const id=randomUUID();
const room=db.collection('online_rooms').doc(id);
const env={...process.env,AURORA_INTERNET_SERVER:'1',AURORA_ROOM_ID:id,AURORA_TEAM_SIZE:String({solo:1,duo:2,squad:4}[mode])};
delete env.AURORA_LAN_BIND;
const child=spawn(process.env.GODOT_BIN||'godot',['--headless','--path',resolve(__dirname,'../../native-godot'),'--script','res://scripts/network/dedicated_server.gd'],{env,stdio:['ignore','pipe','inherit']});
let status='starting',timer,chain=Promise.resolve(),closing=false,accounts=null;
let lastResult=null;
const commitResult=async(result)=>{
  for(let attempt=0;attempt<5;attempt++){
    try{
      await persistRoomResult({firestore:db,roomId:id,result,serverTimestamp:()=>FieldValue.serverTimestamp()});
      console.log('AURORA_ONLINE_RESULT_SAVED');return;
    }catch(err){
      if(attempt===4)throw err;
      await new Promise(resolve=>setTimeout(resolve,500*2**attempt));
    }
  }
};
const update = value => { chain=chain.then(()=>room.set(value,{merge:true})).catch(()=>{child.kill('SIGTERM');process.exitCode=1;}); return chain; };
createInterface({input:child.stdout}).on('line',line=>{
  if (line.startsWith('AURORA_ONLINE READY TLS Internet') && status==='starting') {
    status='open';
    update({status,endpoint,mode,protocol:PROTOCOL,capacity:4,heartbeat:Math.floor(Date.now()/1000),reservations:{}});
    timer=setInterval(()=>{ if(status==='open') update({heartbeat:Math.floor(Date.now()/1000)}); },4000);
  } else if(line.startsWith('AURORA_ROOM_ROSTER ')){
    try{
      const roster=JSON.parse(line.slice('AURORA_ROOM_ROSTER '.length));
      if(roster.room!==id||!Array.isArray(roster.accounts)||roster.accounts.length<1||roster.accounts.length>4||
          roster.accounts.some(x=>typeof x!=='string'||!/^[a-f0-9]{64}$/.test(x))||new Set(roster.accounts).size!==roster.accounts.length)
        throw Error('invalid roster');
      accounts=roster.accounts;
    }catch{child.kill('SIGTERM');process.exitCode=1;}
    return;
  } else if (line.startsWith('V75250_SEALED') && status==='open') {
    if(!accounts){child.kill('SIGTERM');process.exitCode=1;return;}
    status='sealed';clearInterval(timer);update({status,accounts,heartbeat:Math.floor(Date.now()/1000)});
  } else if(line.startsWith('AURORA_ROOM_RESULT ')){
    if(status!=='sealed'||lastResult)return;
    try{
      lastResult=JSON.parse(line.slice('AURORA_ROOM_RESULT '.length));
      chain=chain.then(()=>commitResult(lastResult)).catch(()=>{
        console.error('AURORA_ONLINE_RESULT_SAVE_FAILED');
        process.exitCode=1;child.kill('SIGTERM');
      });
    }catch{process.exitCode=1;child.kill('SIGTERM');}
    return;
  }
  // Never forward pseudonymous account envelopes or credentials to logs.
  console.log(line);
});
async function close(code) {
  if(closing)return;closing=true;clearInterval(timer);status='closed';
  await update({status,heartbeat:Math.floor(Date.now()/1000)});
  process.exitCode=process.exitCode||code;
}
child.on('close',code=>{void close(code||0);});
child.on('error',()=>{void close(1);});
for(const sig of ['SIGTERM','SIGINT'])process.on(sig,()=>child.kill(sig));
