"""Run as root on the authorized EQ Dream host, with an extracted release path."""
from pathlib import Path
import hashlib,json,os,pwd,grp,shutil,subprocess,sys,tarfile,urllib.request
source=Path(sys.argv[1]).resolve();base=Path('/opt/eqemu/tavern-duels');release=base/'releases/20260910.1'
backup=source/'rollback';backup.mkdir(exist_ok=True)
def run(*args):subprocess.run(args,check=True)
try:pwd.getpwnam('eqdream-tavern')
except KeyError:run('useradd','--system','--no-create-home','--shell','/usr/sbin/nologin','eqdream-tavern')
user=pwd.getpwnam('eqdream-tavern');gid=user.pw_gid
state=Path('/var/lib/eqdream-tavern');state.mkdir(exist_ok=True);os.chown(state,0,gid);os.chmod(state,0o750)
for name,mode in [('data',0o700),('tickets',0o2770)]:
 p=state/name;p.mkdir(exist_ok=True);os.chown(p,user.pw_uid if name=='data' else 0,gid);os.chmod(p,mode)
base.mkdir(parents=True,exist_ok=True)
node=base/'node/bin/node'
if not node.exists():
 version='v24.19.0';filename=f'node-{version}-linux-x64.tar.xz';url=f'https://nodejs.org/dist/{version}/'
 sums=urllib.request.urlopen(url+'SHASUMS256.txt',timeout=45).read().decode()
 expected=next(line.split()[0] for line in sums.splitlines() if line.endswith('  '+filename))
 archive=source/filename;urllib.request.urlretrieve(url+filename,archive)
 assert hashlib.sha256(archive.read_bytes()).hexdigest()==expected,'Node checksum mismatch'
 with tarfile.open(archive) as package:package.extractall(base,filter='data')
 (base/f'node-{version}-linux-x64').rename(base/'node')
release.mkdir(parents=True,exist_ok=True)
shutil.copytree(source/'dist-live',release,dirs_exist_ok=True)
config=base/'config.json';config.write_text(json.dumps({'state':str(state/'data'),'tickets':str(state/'tickets'),'port':17867,'origin':'https://triune.siliconsoul.cloud'}));os.chmod(config,0o644)
unit=Path('/etc/systemd/system/eqdream-tavern.service')
if unit.exists():shutil.copy2(unit,backup/unit.name)
unit.write_text(f'''[Unit]
Description=EQ Dream Tavern Duels
After=network.target
[Service]
User=eqdream-tavern
Group=eqdream-tavern
ExecStart={node} {release}/server.mjs {config}
Restart=on-failure
RestartSec=3
UMask=0007
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths={state}
MemoryMax=512M
[Install]
WantedBy=multi-user.target
''')
plugin=Path('/opt/eqemu/server/quests/plugins/tavern_access.pl')
if plugin.exists():shutil.copy2(plugin,backup/plugin.name)
shutil.copy2(source/'live/tavern_access.pl',plugin);os.chmod(plugin,0o644)
run('perl','-c',str(plugin))
player=Path('/opt/eqemu/server/quests/global/global_player.pl');original=player.read_text()
hook="sub EVENT_SAY {\n    # Tavern Duels: private, server-issued character sign-in.\n    if ($text =~ /^!tavern$/i) { plugin::TavernAccess($client); return; }\n"
if 'plugin::TavernAccess($client)' not in original:
 assert original.count('sub EVENT_SAY {')==1,'Ambiguous global speech hook'
 shutil.copy2(player,backup/'global_player.pl');player.write_text(original.replace('sub EVENT_SAY {',hook,1))
nginx=Path('/etc/nginx/sites-enabled/eqemu-patches').resolve();conf=nginx.read_text()
if 'location ^~ /tavern/' not in conf:
 assert conf.count('    location / {')==1,'Ambiguous website route'
 shutil.copy2(nginx,backup/'nginx.conf')
 block='''    location ^~ /tavern/ {
        auth_basic off;
        access_log off;
        client_max_body_size 32k;
        proxy_pass http://127.0.0.1:17867/;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 20s;
    }

'''
 nginx.write_text(conf.replace('    location / {',block+'    location / {',1))
 try:run('nginx','-t')
 except Exception:nginx.write_text(conf);raise
run('systemctl','daemon-reload');run('systemctl','enable','--now','eqdream-tavern')
run('systemctl','reload','nginx')
print('Tavern Duels service, private ticket hook and HTTPS route installed. Existing zones still need a quest reload. Gameplay services were not restarted.')
