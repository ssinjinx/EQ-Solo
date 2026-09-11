"""Exercise the private quest ticket through HTTPS using an isolated QA identity."""
import http.cookiejar,json,re,sqlite3,subprocess,urllib.request
user='eq-live:2147483000'
perl=r'''
require '/opt/eqemu/server/quests/plugins/tavern_access.pl';
package MockTavern;
sub GetBucket { return 0; } sub SetBucket {} sub CharacterID { return 2147483000; }
sub Message { my ($self,$color,$text)=@_; if($text =~ /^\[Tavern Access\] ([a-f0-9]{64})$/) { print $1; } }
package main; TavernAccess(bless {}, 'MockTavern');
'''
token=subprocess.check_output(['perl','-e',perl],text=True)
assert re.fullmatch('[a-f0-9]{64}',token),'Quest plugin did not issue a ticket'
origin='https://triune.siliconsoul.cloud';jar=http.cookiejar.CookieJar();client=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
client.addheaders=[('User-Agent','EQDream-Tavern-Verification/1.0')]
try:

 try:page=client.open(origin+'/tavern/bootstrap?ticket='+token).read().decode()
 except urllib.error.HTTPError as error:
  print('HTTP diagnostic:',error.code,error.headers.get('Server'),error.headers.get('Content-Type'),re.sub('[a-f0-9]{64}','[redacted]',error.read(500).decode(errors='replace')));raise
 assert 'root' in page
 response=client.open(urllib.request.Request(origin+'/tavern/api/game',data=b'{"type":"load"}',headers={'Content-Type':'application/json','Origin':origin})).read()
 profile=json.loads(response);assert 'deck' in profile and profile['packs']['unopened']
 for asset in re.findall(r'(?:src|href)="(/tavern/assets/[^\"]+)"',page):
  data=client.open(origin+asset).read()
  if asset.endswith('.css'):
   for image in re.findall(r'url\((/tavern/[^)]+\.png)\)',data.decode()):assert client.open(origin+image).status==200
 print('Live HTTPS check passed: quest-issued ticket, secure session, API profile, JavaScript, stylesheet and all card-art sheets.')
finally:
 db=sqlite3.connect('/var/lib/eqdream-tavern/data/cards.sqlite',timeout=15)
 with db:
  for table,column in [('tavern_sessions','player'),('packs','owner'),('pack_accounts','owner'),('inventory','owner'),('profiles','id')]:db.execute(f'DELETE FROM {table} WHERE {column}=?',(user,))
 db.close()
