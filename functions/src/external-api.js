'use strict';
const { assignSequentialPlayerId, getAuthenticatedUid } = require('./identity');
const { readPlayerProfile, savePlayerDisplayName } = require('./player-profile');
const { requestOnlineMatch } = require('./online-matchmaking');
const { getOnlineStats } = require('./online-stats');
const MAX_BODY = 8192;
const codes = Object.freeze({
  'invalid-argument':400, 'unauthenticated':401, 'permission-denied':403,
  'not-found':404, 'failed-precondition':400, 'resource-exhausted':429,
  'aborted':409, 'unavailable':503, 'deadline-exceeded':504, 'internal':500
});
class ApiError extends Error {
  constructor(code, message) { super(message); this.code=code; }
}
const fail = (code,message) => new ApiError(code,message);
function respond(res, status, value) {
  res.writeHead(status, {'content-type':'application/json; charset=utf-8',
    'cache-control':'no-store','x-content-type-options':'nosniff'});
  res.end(JSON.stringify(value));
}
function sendError(res,error) {
  const code=error instanceof ApiError && Object.hasOwn(codes,error.code) ? error.code : 'internal';
  respond(res,codes[code],{error:{status:code.toUpperCase().replaceAll('-','_'),
    message:code==='internal' ? 'Account service error' : error.message}});
}
function token(value) {
  return typeof value==='string' && value.length<=8192 && /^[A-Za-z0-9_.-]+$/.test(value) ? value : null;
}
async function body(req) {
  const chunks=[]; let count=0;
  for await(const chunk of req) {
    count+=chunk.length;
    if(count>MAX_BODY)throw fail('invalid-argument','Request too large');
    chunks.push(chunk);
  }
  let value;
  try { value=JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { throw fail('invalid-argument','Invalid JSON'); }
  if(!value || typeof value!=='object' || Array.isArray(value) ||
      Object.keys(value).length!==1 || !Object.hasOwn(value,'data'))
    throw fail('invalid-argument','Expected callable data envelope');
  return value.data;
}
function createExternalHandler({firestore,verifyAuth,verifyApp,appId,serverTimestamp,signingKey=''}) {
  if(!appId || typeof verifyAuth!=='function' || typeof verifyApp!=='function')
    throw Error('Exact Firebase app and token verifiers required');
  const routes=Object.freeze({
    ensurePlayerIdentity: async request => ({number:await assignSequentialPlayerId({
      firestore,uid:getAuthenticatedUid(request,fail),serverTimestamp,createError:fail})}),
    getPlayerProfile: request=>readPlayerProfile({firestore,request,createError:fail}),
    setPlayerDisplayName: request=>savePlayerDisplayName({firestore,request,serverTimestamp,createError:fail}),
    getOnlineStats: request=>getOnlineStats({firestore,request,createError:fail}),
    requestOnlineMatch: request=>requestOnlineMatch({firestore,request,signingKey,createError:fail})
  });
  const rates=new Map(); let inFlight=0;
  return async(req,res)=>{
    if(req.method==='GET' && req.url==='/healthz')return respond(res,200,{status:'ok'});
    const name=/^\/api\/([A-Za-z]+)$/.exec(req.url||'')?.[1];
    if(req.method!=='POST'||!name||!Object.hasOwn(routes,name))
      return sendError(res,fail('not-found','Unknown route'));
    if(inFlight>=16)return sendError(res,fail('resource-exhausted','Service busy'));
    inFlight++;
    try {
      if(!/^application\/json(?:\s*;.*)?$/i.test(req.headers['content-type']||''))
        throw fail('invalid-argument','JSON required');
      const auth=typeof req.headers.authorization==='string'
        ? /^Bearer (.+)$/.exec(req.headers.authorization)?.[1] : null;
      const authToken=token(auth), appToken=token(req.headers['x-firebase-appcheck']);
      if(!authToken||!appToken)throw fail('unauthenticated','Verified account and app required');
      let verified, app;
      try { [verified,app]=await Promise.all([verifyAuth(authToken),verifyApp(appToken)]); }
      catch { throw fail('unauthenticated','Invalid account or app token'); }
      if(!verified?.uid||app?.appId!==appId)
        throw fail('permission-denied','Application not permitted');
      const now=Date.now();
      if(rates.size>=4096)for(const [uid,v] of rates)if(v.until<=now)rates.delete(uid);
      let rate=rates.get(verified.uid);
      if(!rate||rate.until<=now) {
        if(!rate&&rates.size>=4096)throw fail('resource-exhausted','Service busy');
        rate={until:now+60000,count:0};rates.set(verified.uid,rate);
      }
      if(++rate.count>30)throw fail('resource-exhausted','Try again later');
      const data=await body(req);
      const result=await routes[name]({auth:{uid:verified.uid},app:{appId:app.appId},data});
      respond(res,200,{result});
    } catch(error) {
      if(!res.headersSent&&!res.destroyed)sendError(res,error);
    } finally { inFlight--; }
  };
}
module.exports={createExternalHandler};
