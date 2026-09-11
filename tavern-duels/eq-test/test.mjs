import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import http from 'node:http';
import {startServer} from './server.mjs';
const state=mkdtempSync(join(tmpdir(),'tavern-test-'));
let service=await startServer({port:0,state});
async function login(character){
 const ticket=service.issueTicket(character);
 const response=await fetch(`${service.origin}/bootstrap?ticket=${ticket}`,{redirect:'manual'});
 assert.equal(response.status,303);
 assert.match(response.headers.get('set-cookie'),/HttpOnly; SameSite=Strict/);
 assert.equal((await fetch(`${service.origin}/bootstrap?ticket=${ticket}`)).status,401,'tickets cannot be replayed');
 return response.headers.get('set-cookie').split(';')[0];
}
async function call(cookie,body,origin=service.origin){return fetch(service.origin+'/api/game',{method:'POST',headers:{'Content-Type':'application/json',Origin:origin,Cookie:cookie},body:JSON.stringify(body)})}
try{
 assert.equal((await call('',{type:'load'})).status,401);
 assert.equal((await fetch(service.origin+'/api/game',{method:'POST',headers:{'oai-authenticated-user-id':'admin'}})).status,401,'Sites identity headers grant no local access');
 const alice=await login('Alice'),bob=await login('Bob');
 assert.equal((await call(alice,{type:'load'},'https://evil.example')).status,403);
 const badHost=await new Promise((ok,no)=>{http.get(service.origin+'/health',{headers:{Host:'evil.example'}},res=>{res.resume();ok(res.statusCode)}).on('error',no)});
 assert.equal(badHost,403);
 assert.equal((await fetch(service.origin+'/',{headers:{Cookie:alice}})).status,200);
 assert.equal((await fetch(service.origin+'/%2e%2e%2fpackage.json',{headers:{Cookie:alice}})).status,404);
 let a=await (await call(alice,{type:'claim_starter',clan:'Warrior'})).json();
 assert.equal(a.packs.starterClan,'Warrior');
 await call(bob,{type:'claim_starter',clan:'Necromancer'});
 a=await (await call(alice,{type:'new'})).json();
 const version=a.version;
 a=await (await call(alice,{type:'action',version,action:{type:'pass'}})).json();
 assert.ok(a.version>version);
 assert.equal((await call(alice,{type:'action',version,action:{type:'pass'}})).status,400);
 const savedCollection=a.collection;
 await service.close();service=await startServer({port:0,state});
 assert.equal((await call(alice,{type:'load'})).status,401,'restart invalidates sessions');
 const resumed=await (await call(await login('Alice'),{type:'load'})).json();
 assert.deepEqual(resumed.collection,savedCollection,'cards persist across restart');
 assert.equal(resumed.version,a.version);assert.deepEqual(resumed.game,a.game,'duel persists');
 console.log('EQ adapter passed: loopback host/origin checks, authentication, one-use tickets, no Sites-header impersonation, path containment, starter, practice action, stale action and persistent restart.');
}finally{await service.close();rmSync(state,{recursive:true,force:true});}
