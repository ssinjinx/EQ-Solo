from pathlib import Path
import hashlib,json,os,shutil,zipfile
r=Path('/opt/eqemu/staging/tavern-live-20260910');web=Path('/var/www/eqemu-patches');live=web/'live';payload=r/'player-payload'
old=json.loads((live/'manifest.json').read_text());assert old['version']=='2026.09.10.4','Unexpected live release'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for e in old['files']:assert sha(live/e['path'])==e['sha256'],e['path']
patch=r/'launcher-patch';patch.mkdir(exist_ok=True)
for e in old['files']:
 name=Path(e['path']);assert not name.is_absolute() and '..' not in name.parts
 target=patch/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(live/name,target)
changes=[]
for p in payload.rglob('*'):
 if p.is_file():
  name='SoloAssist/'+p.relative_to(payload).as_posix();target=patch/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target);changes.append(name)
instructions=(r/'live/README.md').read_text()
readme=patch/'SoloAssist/README.txt';readme.write_text(readme.read_text()+'\n\nTAVERN DUELS — 2026.09.10.5\n'+instructions);changes.append('SoloAssist/README.txt')
entries={e['path']:dict(e) for e in old['files']}
for name in changes:
 p=patch/name;entries[name]=dict(entries.get(name,{}),path=name,size=p.stat().st_size,sha256=sha(p))
manifest=dict(old,version='2026.09.10.5',files=list(entries.values()))
(patch/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
with zipfile.ZipFile(patch/'eqemu-custom-patch.zip','w',zipfile.ZIP_DEFLATED) as z:
 for name in list(entries)+['manifest.json']:z.write(patch/name,name)
newFiles={p.relative_to(payload).as_posix():p.read_bytes() for p in payload.rglob('*') if p.is_file()}
bundles=['EQDream-MacroQuest-Solo-Assist.zip','EQDream-Solo-Assist-Update.zip']
for name in bundles:
 full=name==bundles[0]
 additions={k:v for k,v in newFiles.items() if not full or k.startswith(('lua/','TavernDuels/'))}
 with zipfile.ZipFile(live/name) as src,zipfile.ZipFile(patch/name,'w',zipfile.ZIP_DEFLATED) as dst:
  existing=set()
  for info in src.infolist():
   key=info.filename;data=src.read(key);existing.add(key)
   if key in additions:data=additions[key]
   if key=='config/ingame.cfg' and full and b'eqdream_tavern_live' not in data:data+=b'\r\n/lua run eqdream_tavern_live quiet\r\n'
   if key.endswith('README.txt') or key=='EQDream-START-HERE.txt':data+=('\n\nTAVERN DUELS\n'+instructions).encode()
   dst.writestr(info,data)
  for key,data in additions.items():
   if key not in existing:dst.writestr(key,data)
  if full:dst.writestr('config/tavern-live/',b'')
html=web/'index.html';before=html.read_text();assert 'id="tavern-duels"' not in before
section='''<section id="tavern-duels"><h2>Tavern Duels — play cards inside EQ</h2><p>Type <strong>/tavern</strong> to open the battlefield, packs, decks and trading post. Your cards are saved to your EQ character on the server. Play practice duels, share a table code with another player, or trade cards.</p><h3>Install or update</h3><ol><li>Close EQ and run the launcher’s <strong>Patch / Repair</strong>.</li><li>Open <strong>SoloAssist</strong> in your EQ folder. Run <strong>Install-Solo-Assist.cmd</strong> and select your MacroQuest folder.</li><li>Start MacroQuest and EQ Dream, log in, then type <strong>/tavern</strong>.</li></ol><p>The updated <a href="/live/EQDream-MacroQuest-Solo-Assist.zip">full MacroQuest bundle</a> includes Tavern Duels. Existing users can also download the <a href="/live/EQDream-Solo-Assist-Update.zip">small update</a>. Extract the entire ZIP before installing. Requires windowed EQ and <a href="https://developer.microsoft.com/en-us/microsoft-edge/webview2/">Microsoft WebView2 Runtime</a>.</p><p>Choose a starter in Packs, then open your welcome packs. Use <strong>/tavern close</strong> to close the window. If the command is missing, type <strong>/lua run eqdream_tavern_live</strong>. Live cards are separate from test cards and do not change EQ items, SSF or currency.</p></section>'''
assert '</main>' in before;(patch/'index.html').write_text(before.replace('</main>',section+'\n</main>',1))
for name in bundles+['eqemu-custom-patch.zip']:
 with zipfile.ZipFile(patch/name) as z:assert z.testzip() is None
with zipfile.ZipFile(patch/'eqemu-custom-patch.zip') as z:
 for e in manifest['files']:assert hashlib.sha256(z.read(e['path'])).hexdigest()==e['sha256']
rollback=r/'launcher-rollback';rollback.mkdir(exist_ok=False)
names=changes+bundles+['eqemu-custom-patch.zip','manifest.json']
for name in names:
 if (live/name).exists():target=rollback/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(live/name,target)
shutil.copy2(html,rollback/'index.html')
assert json.loads((live/'manifest.json').read_text())==old and html.read_text()==before
def atomic(src,dst):
 dst.parent.mkdir(parents=True,exist_ok=True);tmp=dst.with_name(dst.name+'.tavern-new');shutil.copy2(src,tmp);os.chmod(tmp,0o644);os.replace(tmp,dst)
for name in names:atomic(patch/name,live/name)
atomic(patch/'index.html',html)
for e in manifest['files']:assert sha(live/e['path'])==e['sha256']
print('Published 2026.09.10.5: Tavern Duels launcher files, both bundles, manual patch and website; all '+str(len(entries))+' payload hashes verified.')
