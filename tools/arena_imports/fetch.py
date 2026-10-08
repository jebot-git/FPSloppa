"""Inventory the requested arena collections and retain hash-pinned source archives."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.request import urlopen
from urllib.parse import urljoin,urlparse
import concurrent.futures,hashlib,json,zipfile,struct
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).parent;LOCAL=HERE/'local'
class Links(HTMLParser):
 def __init__(self):super().__init__();self.links=[]
 def handle_starttag(self,t,a):
  if t=='a' and dict(a).get('href'):self.links.append(dict(a)['href'])
def fetch(row):
 p=LOCAL/row['archive']
 if not p.exists():p.write_bytes(urlopen(row['url'],timeout=90).read())
 data=p.read_bytes();row.update(bytes=len(data),sha256=hashlib.sha256(data).hexdigest())
 with zipfile.ZipFile(p) as z:
  assert sum(i.file_size for i in z.infolist())<1_000_000_000
  row['files']=[{'name':i.filename,'bytes':i.file_size} for i in z.infolist() if not i.is_dir()]
 return row
def main():
 LOCAL.mkdir(exist_ok=True);rows=[{'collection':'q30','archive':'q30-download','url':'https://www.slipseer.com/index.php?resources/q30-deathmatch-jam.628/download'}]
 pages={}
 for section in ['quake1','quake2','quake3','q2w','doom','other']:
  url='https://maps.rcmd.org/'+section+'/';text=urlopen(url,timeout=30).read().decode();pages[url]=text;p=Links();p.feed(text)
  for link in p.links:
   full=urljoin(url,link)
   if urlparse(full).netloc=='maps.rcmd.org' and full.lower().endswith(('.zip','.pk3','.pak')):
    rows.append({'collection':'rcmd_'+section,'archive':section+'_'+full.rsplit('/',1)[-1],'url':full})
 unique={r['url']:r for r in rows}
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:result=list(pool.map(fetch,unique.values()))
 (HERE/'sources.json').write_text(json.dumps(result,indent=2)+'\n')
 for row in result:print(row['collection'],row['archive'],row['bytes'])
if __name__=='__main__':main()
