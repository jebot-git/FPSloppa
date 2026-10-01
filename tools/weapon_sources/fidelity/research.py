"""Cache the user supplied public model pages and their license/download metadata."""
import concurrent.futures, hashlib, json, pathlib, requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin
ROOT=pathlib.Path(__file__).resolve().parent
CACHE=ROOT/'research'; CACHE.mkdir(exist_ok=True)
(CACHE/'.gdignore').touch()
def examine(url):
    key=url.rstrip('/').split('/')[-1]
    path=CACHE/(key+'.html')
    try:
        if not path.exists():
            response=requests.get(url,timeout=45);response.raise_for_status();path.write_text(response.text)
        soup=BeautifulSoup(path.read_text(),'html.parser')
        body=soup.select_one('article') or soup.select_one('#content') or soup
        text=body.get_text(' ',strip=True)
        links=[{'text':a.get_text(' ',strip=True),'url':urljoin(url,a['href'])} for a in soup.select('a[href]')]
        relevant=[a for a in links if any(x in a['url'].lower() for x in ['creativecommons','licenses/','download','/files/','.zip','.blend','.7z']) or 'license' in a['text'].lower()]
        images=[urljoin(url,a.get('src','')) for a in soup.select('img') if any(x in a.get('src','') for x in ['/files/','/blends/','/storage/'])]
        result={'url':url,'title':soup.title.get_text(strip=True) if soup.title else key,'links':relevant,'images':images,'text':text,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    except Exception as e:result={'url':url,'error':str(e)}
    return result
if __name__=='__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:results=list(pool.map(examine,json.loads((ROOT/'urls.json').read_text())))
    (ROOT/'research.json').write_text(json.dumps(results,indent=2))
    for r in results:
        print(r.get('title',r['url']),r.get('error',''),[(x['text'],x['url']) for x in r.get('links',[]) if 'creativecommons' in x['url'] or '/download' in x['url'] or any(e in x['url'] for e in ['.zip','.blend','.7z'])])
