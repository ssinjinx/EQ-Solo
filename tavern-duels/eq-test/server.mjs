import http from 'node:http';
import {randomBytes} from 'node:crypto';
import {readFileSync,mkdirSync,existsSync,readdirSync,unlinkSync,statSync} from 'node:fs';
import {resolve,extname,sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawn} from 'node:child_process';
import {database} from './database.mjs';
import {gameService} from './rules.mjs';
const root=fileURLToPath(new URL('../',import.meta.url));
export async function startServer({port=17865,state=resolve(root,'.eq-test-state'),queue,clientPath,hostPath}={}){
 mkdirSync(state,{recursive:true});
 const db=database(resolve(state,'tavern.sqlite'));
 const tickets=new Map(),sessions=new Map(),hosts=new Map();
 let serial=Promise.resolve(),origin;
 const secret=()=>randomBytes(32).toString('hex');
 function issueTicket(character){
  if(!/^[A-Za-z][A-Za-z0-9_]{2,31}$/.test(character))throw Error('Invalid character');
  const key=secret();tickets.set(key,{user:'eq-test:'+character.toLowerCase(),expires:Date.now()+30000});return key;
 }
 const webRoot=resolve(root,'dist-eq');
 const server=http.createServer(async(req,res)=>{
  const reply=(status,value)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(value));};
  res.setHeader('Cache-Control','no-store');res.setHeader('Referrer-Policy','no-referrer');res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('X-Frame-Options','DENY');
  if(req.headers.host!==new URL(origin).host)return reply(403,{error:'Local requests only.'});
  try{
   const url=new URL(req.url,origin);
   if(req.method==='GET'&&url.pathname==='/health')return reply(200,{service:'eq-tavern-test',ready:true});
   if(req.method==='GET'&&url.pathname==='/bootstrap'){
    const key=url.searchParams.get('ticket'),ticket=tickets.get(key);tickets.delete(key);
    if(!ticket||ticket.expires<Date.now())return reply(401,{error:'Reopen the window with /bored.'});
    const session=secret();sessions.set(session,{user:ticket.user,expires:Date.now()+12*3600000});
    res.writeHead(303,{'Location':'/','Set-Cookie':`eq_tavern=${session}; HttpOnly; SameSite=Strict; Path=/; Max-Age=43200`});return res.end();
   }
   const cookie=(req.headers.cookie||'').split(';').map(s=>s.trim()).find(s=>s.startsWith('eq_tavern='));
   const session=sessions.get(cookie?.slice(10));
   if(!session||session.expires<Date.now())return reply(401,{error:'Open Tavern Duels from the test character with /bored.'});
   if(req.method==='POST'&&url.pathname==='/api/game'){
    if(req.headers.origin!==origin||!/^application\/json(?:;|$)/i.test(req.headers['content-type']||''))return reply(403,{error:'Invalid request origin.'});
    let raw='';for await(const chunk of req){raw+=chunk;if(Buffer.byteLength(raw)>32768)return reply(413,{error:'Request too large.'});}
    let body;try{body=JSON.parse(raw)}catch{return reply(400,{error:'Invalid JSON.'})}
    const operation=serial.then(()=>gameService(db,session.user,body));serial=operation.catch(()=>{});
    try{return reply(200,await operation)}catch(e){return reply(400,{error:e.message})}
   }
   if(req.method!=='GET')return reply(405,{error:'Method unavailable.'});
   const file=resolve(webRoot,'.'+decodeURIComponent(url.pathname==='/'?'/index.html':url.pathname));
   if(!file.startsWith(webRoot+sep)||!existsSync(file)||!statSync(file).isFile())return reply(404,{error:'Not found.'});
   res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'");
   res.setHeader('Content-Type',({'.html':'text/html; charset=utf-8','.js':'text/javascript','.css':'text/css','.png':'image/png','.svg':'image/svg+xml','.woff2':'font/woff2'})[extname(file)]||'application/octet-stream');
   res.end(readFileSync(file));
  }catch{if(!res.headersSent)reply(500,{error:'Test service error.'});else res.end();}
 });
 await new Promise((ok,no)=>{server.once('error',no);server.listen(port,'127.0.0.1',ok)});
 origin=`http://127.0.0.1:${server.address().port}`;
 let timer;
 if(queue){
  if(!clientPath||!hostPath)throw Error('Test client and window host paths are required.');
  mkdirSync(queue,{recursive:true});
  // Queue is local desktop IPC. It grants no production EQ account authority.
  // Discard old commands after service restart.
  for(const name of readdirSync(queue))if(/^request-\d+\.json$/.test(name))unlinkSync(resolve(queue,name));
  timer=setInterval(()=>{
   for(const [key,value] of tickets)if(value.expires<Date.now())tickets.delete(key);
   for(const [key,value] of sessions)if(value.expires<Date.now())sessions.delete(key);
   for(const name of readdirSync(queue).filter(n=>/^request-\d+\.json$/.test(n))){
    const path=resolve(queue,name);
    try{
     const request=JSON.parse(readFileSync(path,'utf8'));unlinkSync(path);
     if(!Number.isSafeInteger(request.pid)||request.pid<=0||name!==`request-${request.pid}.json`||!['toggle','close'].includes(request.action))continue;
     const prior=hosts.get(request.pid);
     if(prior){prior.stdin.write('close\n');hosts.delete(request.pid);if(request.action==='toggle'&&prior.character===request.character)continue;}
     if(request.action==='close')continue;
     const ticket=issueTicket(request.character);
     const child=spawn(hostPath,[String(request.pid),clientPath,`${origin}/bootstrap?ticket=${ticket}`,resolve(state,'webview',request.character.toLowerCase())],{stdio:['pipe','ignore','pipe'],windowsHide:false});
     child.character=request.character;hosts.set(request.pid,child);
     child.stderr.on('data',data=>process.stderr.write(data));
     const cleanup=()=>{if(hosts.get(request.pid)===child)hosts.delete(request.pid);tickets.delete(ticket);};
     child.on('exit',cleanup);child.on('error',e=>{cleanup();console.error('Window launch failed:',e.message)});
    }catch(e){try{unlinkSync(path)}catch{}console.error('Bridge request failed:',e.message)}
   }
  },250);
 }
 return {origin,issueTicket,async close(){clearInterval(timer);for(const child of hosts.values())child.stdin.end('close\n');await new Promise(ok=>server.close(ok));await serial;db.close()}};
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const configPath=process.argv[2];if(!configPath)throw Error('Pass a local test configuration file.');
 const service=await startServer(JSON.parse(readFileSync(configPath,'utf8')));
 console.log('Tavern Duels test service ready at '+service.origin);
 for(const signal of ['SIGINT','SIGTERM'])process.on(signal,async()=>{await service.close();process.exit(0)});
}
