'use strict';
const {createServer}=require('node:http');
const {initializeApp,applicationDefault}=require('firebase-admin/app');
const {getAuth}=require('firebase-admin/auth');
const {getAppCheck}=require('firebase-admin/app-check');
const {getFirestore,FieldValue}=require('firebase-admin/firestore');
const {initializeEmptyPlayerCounter}=require('./identity');
const {createExternalHandler}=require('./external-api');
const PROJECT_ID='thedemianff-last-zone';
async function main(){
  const appId=process.env.AURORA_FIREBASE_APP_ID;
  if(!/^1:[0-9]+:android:[0-9a-f]+$/i.test(appId||''))throw Error('Configure exact preview Firebase app ID');
  initializeApp({projectId:PROJECT_ID,credential:applicationDefault()});
  const firestore=getFirestore();
  // Never reset an existing counter or invent IDs if old identities exist.
  await initializeEmptyPlayerCounter({firestore,createError:(code,message)=>Object.assign(new Error(message),{code})});
  const handler=createExternalHandler({firestore,appId,
    verifyAuth:token=>getAuth().verifyIdToken(token,true),
    verifyApp:token=>getAppCheck().verifyToken(token),
    serverTimestamp:()=>FieldValue.serverTimestamp(),
    signingKey:process.env.AURORA_MATCH_SIGNING_KEY||''});
  const server=createServer(handler);
  server.requestTimeout=15000;
  server.headersTimeout=10000;
  server.listen(Number(process.env.PORT||10000),'0.0.0.0',()=>console.log('Aurora account API ready'));
}
main().catch(()=>{console.error('Aurora account API startup failed; check exact app ID, ADC permissions, Firestore and counter audit.');process.exitCode=1;});
