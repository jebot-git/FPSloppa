"""Inventory requested UT99 maps, retaining explicit player-capacity evidence."""
from pathlib import Path
from urllib.parse import urljoin
import concurrent.futures,html,re,json,subprocess,hashlib
HERE=Path(__file__).resolve().parent;LOCAL=HERE/'local';LOCAL.mkdir(exist_ok=True)
BASE='https://unrealarchive.org/unreal-tournament/maps/'
def get(url):
 p=LOCAL/(hashlib.sha256(url.encode()).hexdigest()+'.html')
 if not p.exists():subprocess.run(['curl','-fLsS','--retry','2','--max-time','60',url,'-o',str(p)],check=True)
 return p.read_text()
def plain(s):return ' '.join(html.unescape(re.sub('<[^>]+>',' ',s)).split())
def rows(url):
 out=[]
 for tr in re.findall(r'<tr\b[^>]*>(.*?)</tr>',get(url),re.S|re.I):
  cells=re.findall(r'<td\b[^>]*>(.*?)</td>',tr,re.S|re.I)
  if len(cells)<4:continue
  a=re.search(r'<a\s+href="([^"]+)"[^>]*>(.*?)</a>',cells[0],re.S)
  if not a:continue
  name=plain(a[2]);players=plain(cells[3]);numbers=[int(n) for n in re.findall(r'\d+',players)]
  if not name.lower().startswith(('as-','koth-','koth_')):continue
  out.append({'name':name,'title':plain(cells[1]),'author':plain(cells[2]),'players':players,'declared_capacity':max(numbers) if numbers else None,'page':urljoin(url,html.unescape(a[1])),'index':url})
 return out
def main():
 chaos=BASE+'chaosut/index.html';assault=BASE+'assault/index.html'
 links={assault}
 for link in re.findall(r'href="([^"]+index\.html)"',get(assault)):
  u=urljoin(assault,link)
  if u.startswith(BASE+'assault/'):links.add(u)
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:allrows=sum(list(pool.map(rows,[chaos,*sorted(links)])),[])
 seen=set();result=[]
 for row in allrows:
  if row['page'] in seen:continue
  seen.add(row['page']);row['mode']='koth' if row['name'].lower().startswith('koth') else 'as';row['eligible']=row['mode']=='koth' or row['declared_capacity'] is not None and row['declared_capacity']>=8
  row['selection_reason']='KOTH-prefixed ChaosUT map' if row['mode']=='koth' else 'Explicit capacity at least 8' if row['eligible'] else 'Unknown capacity or below 8'
  result.append(row)
 (HERE/'catalog.json').write_text(json.dumps(result,indent=2)+'\n')
 print('Index pages',len(links),'KOTH',sum(r['mode']=='koth' for r in result),'AS',sum(r['mode']=='as' for r in result),'AS eligible',sum(r['eligible'] and r['mode']=='as' for r in result),flush=True)

if __name__=='__main__':main()
