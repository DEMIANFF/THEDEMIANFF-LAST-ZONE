'use strict';
const crypto = require('node:crypto');
const PROTOCOL = 31;
const MODES = new Set(['solo','duo','squad']);
const TICKET_TTL = 45;
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
function validEndpoint(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'wss:' && !url.username && !url.password && !url.search && !url.hash &&
      /^[a-z0-9.-]+$/i.test(url.hostname) && url.hostname.includes('.') &&
      !/^\d+\.\d+\.\d+\.\d+$/.test(url.hostname) && !url.hostname.endsWith('.local') &&
      !url.hostname.endsWith('.localhost') && url.hostname !== 'localhost';
  } catch { return false; }
}
function issueTicket({room, sub, nonce, exp, signingKey}) {
  if (!/^[0-9a-f]{64}$/i.test(signingKey)) throw new Error('match key unavailable');
  const payload = Buffer.from(JSON.stringify({v:PROTOCOL,room,sub,nonce,exp})).toString('base64');
  return payload + '.' + crypto.createHmac('sha256',Buffer.from(signingKey,'hex')).update(payload).digest('hex');
}
async function requestOnlineMatch({firestore, request, signingKey, createError, now = Math.floor(Date.now()/1000)}) {
  const uid = request.auth?.uid;
  if (!uid || !request.app) throw createError('unauthenticated','Verified account and app required');
  const mode = request.data?.mode;
  if (!MODES.has(mode) || request.data?.protocol !== PROTOCOL)
    throw createError('failed-precondition','Unsupported mode or protocol');
  if (!/^[0-9a-f]{64}$/i.test(signingKey)) throw createError('unavailable','Match service not configured');
  const sub = hash(uid);
  const candidates = await firestore.collection('online_rooms').where('status','==','open').limit(40).get();
  for (const candidate of candidates.docs) {
    const entry = await firestore.runTransaction(async tx => {
      const roomRef = candidate.ref;
      const assignmentRef = firestore.collection('online_assignments').doc(sub);
      const [snapshot, assignment] = await Promise.all([tx.get(roomRef),tx.get(assignmentRef)]);
      const room = snapshot.data();
      const previous = assignment.data();
      if (previous && previous.exp > now && previous.room !== roomRef.id) return null;
      if (!room || room.status !== 'open' || room.mode !== mode || room.protocol !== PROTOCOL ||
          room.heartbeat < now-12 || room.heartbeat > now+5 || room.capacity !== 4 ||
          !validEndpoint(room.endpoint)) return null;
      const reservations = Object.fromEntries(Object.entries(room.reservations || {}).filter(([,v]) => v.exp > now));
      if (!reservations[sub] && Object.keys(reservations).length >= room.capacity) return null;
      const reservation = reservations[sub] || {nonce:crypto.randomBytes(18).toString('hex'),exp:now+TICKET_TTL};
      reservations[sub] = reservation;
      tx.update(roomRef,{reservations});
      tx.set(assignmentRef,{room:roomRef.id,exp:reservation.exp});
      return {endpoint:room.endpoint,room:roomRef.id,...reservation};
    });
    if (entry) return {endpoint:entry.endpoint,ticket:issueTicket({...entry,sub,signingKey}),expires:entry.exp};
  }
  throw createError('unavailable','No live compatible rooms');
}
module.exports = {PROTOCOL, validEndpoint, issueTicket, requestOnlineMatch};
