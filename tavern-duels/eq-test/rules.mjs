// Use the same authoritative game service as the website, without Cloudflare dependencies.
import ts from 'typescript';
import {readFileSync} from 'node:fs';
const url=source=>'data:text/javascript;base64,'+Buffer.from(source).toString('base64');
function compile(name,replacements={}){
 let js=ts.transpileModule(readFileSync(new URL('../lib/'+name+'.ts',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.ESNext,target:ts.ScriptTarget.ES2022}}).outputText;
 for(const [from,to] of Object.entries(replacements))js=js.replaceAll("from '"+from+"'","from '"+to+"'");
 return url(js);
}
const game=compile('game');
const packs=compile('packs',{'./game':game});
export const {gameService}=await import(compile('game-service',{'./game':game,'./packs':packs}));
