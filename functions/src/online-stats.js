'use strict';
const {createHash}=require('node:crypto');
const subFor=uid=>createHash('sha256').update(uid).digest('hex');
const integer=(v,min,max)=>Number.isSafeInteger(v)&&v>=min&&v<=max;
const hex=v=>typeof v==='string'&&/^[0-9a-f]{64}$/.test(v);
const fields=['played','wins','kills','hits','abandoned','seconds'];
const empty=()=>Object.fromEntries(fields.map(k=>[k,0]));
function readStats(snapshot) {
  if (!snapshot.exists) return empty();
  const data=snapshot.data();
  if (data.schema!==1 || fields.some(k=>!integer(data[k],0,Number.MAX_SAFE_INTEGER-100000)))
    throw new Error('Invalid server stats');
  return Object.fromEntries(fields.map(k=>[k,data[k]]));
}
function validateResult(result,roomId,accounts,mode) {
  if (!result || result.room!==roomId || typeof result.completed!=='boolean' ||
      !integer(result.seconds,0,7200) || !Array.isArray(result.records) ||
      !Array.isArray(accounts) || accounts.length<1 || accounts.length>4 ||
      accounts.some(x=>!hex(x)) || new Set(accounts).size!==accounts.length ||
      result.records.length!==accounts.length) throw Error('Invalid match envelope');
  const seen=new Set(), slots=new Set();
  let winners=0,kills=0;
  for (const r of result.records) {
    if (!r || !hex(r.sub) || !accounts.includes(r.sub) || seen.has(r.sub) ||
        !integer(r.slot,0,3) || slots.has(r.slot) || !integer(r.kills,0,49) ||
        !integer(r.hits,0,100000) || typeof r.won!=='boolean' ||
        typeof r.abandoned!=='boolean' || (r.won&&(!result.completed||r.abandoned)))
      throw Error('Invalid player match record');
    seen.add(r.sub);slots.add(r.slot);winners+=Number(r.won);kills+=r.kills;
  }
  if(kills>49||winners>({solo:1,duo:2,squad:4}[mode]||0))throw Error('Impossible match outcome');
}
async function persistRoomResult({firestore,roomId,result,serverTimestamp}) {
  const roomRef=firestore.collection('online_rooms').doc(roomId);
  const receiptRef=firestore.collection('online_match_receipts').doc(roomId);
  return firestore.runTransaction(async tx=>{
    const [roomSnap,receipt]=await Promise.all([tx.get(roomRef),tx.get(receiptRef)]);
    if(receipt.exists)return {duplicate:true};
    const room=roomSnap.data();
    if(!room||room.status!=='sealed')throw Error('Room not sealed');
    validateResult(result,roomId,room.accounts,room.mode);
    const refs=result.records.map(r=>firestore.collection('online_player_stats').doc(r.sub));
    const snapshots=await Promise.all(refs.map(ref=>tx.get(ref)));
    const next=result.records.map((r,n)=>{
      const previous=readStats(snapshots[n]);
      return {schema:1,played:previous.played+1,wins:previous.wins+Number(r.won),
        kills:previous.kills+r.kills,hits:previous.hits+r.hits,
        abandoned:previous.abandoned+Number(r.abandoned),
        seconds:previous.seconds+(r.abandoned?0:result.seconds),updatedAt:serverTimestamp()};
    });
    refs.forEach((ref,n)=>tx.set(ref,next[n]));
    tx.create(receiptRef,{schema:1,room:roomId,mode:room.mode,completed:result.completed,seconds:result.seconds,
      accounts:room.accounts,createdAt:serverTimestamp()});
    tx.update(roomRef,{status:'finished',finishedAt:serverTimestamp()});
    return {duplicate:false};
  });
}
async function getOnlineStats({firestore,request,createError}) {
  const uid=request.auth?.uid;
  if(!uid||!request.app)throw createError('unauthenticated','Verified account and app required');
  if(request.data!=null&&(typeof request.data!=='object'||Array.isArray(request.data)||Object.keys(request.data).length))
    throw createError('invalid-argument','No player identifier accepted');
  const identity=await firestore.collection('player_identities').doc(uid).get();
  if(!integer(identity.data()?.number,1,99999))throw createError('failed-precondition','Permanent identity required');
  const snap=await firestore.collection('online_player_stats').doc(subFor(uid)).get();
  return {schema:1,...readStats(snap),ranked:false};
}
module.exports={persistRoomResult,getOnlineStats,validateResult,subFor};
