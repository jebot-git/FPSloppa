"""Download public CC0 archives and source previews, without account access."""
import concurrent.futures,hashlib,json,pathlib,requests,zipfile
from urllib.parse import urljoin,unquote,urlparse
from bs4 import BeautifulSoup
ROOT=pathlib.Path(__file__).resolve().parent
SOURCES=ROOT/'sources';SOURCES.mkdir(exist_ok=True);(SOURCES/'.gdignore').touch()
PREVIEWS=ROOT/'previews';PREVIEWS.mkdir(exist_ok=True);(PREVIEWS/'.gdignore').touch()
def get(url,path):
    if not path.exists():
        r=requests.get(url,timeout=120);r.raise_for_status();path.write_bytes(r.content)
    return hashlib.sha256(path.read_bytes()).hexdigest()
def download(r):
    key=r['url'].split('/')[-1];result={'source':r['url'],'files':[]}
    try:
        soup=BeautifulSoup((ROOT/'research'/(key+'.html')).read_text(),'html.parser')
        if 'blendswap' in r['url']:
            pics=[urljoin(r['url'],i['src']) for i in soup.select('img[src]') if '/blend_previews/'+key+'/' in i['src']]
            result['use']='visual reference; public file download requires sign-in'
        else:
            pics=[i for i in r['images'] if '/styles/medium/' in i]
            for a in r['links']:
                url=a['url']
                if not any(url.lower().endswith(e) for e in ['.zip','.blend']):continue
                folder=SOURCES/key;folder.mkdir(exist_ok=True)
                path=folder/unquote(urlparse(url).path.split('/')[-1]);sha=get(url,path)
                result['files'].append({'url':url,'path':str(path.relative_to(ROOT)),'sha256':sha})
                if path.suffix=='.zip':
                    dest=folder/'unpacked';dest.mkdir(exist_ok=True)
                    with zipfile.ZipFile(path) as z:
                        for info in z.infolist():
                            target=(dest/info.filename).resolve()
                            if target.is_relative_to(dest.resolve()):z.extract(info,dest)
        if pics:
            get(pics[0],PREVIEWS/(key+'.jpg'));result['preview']=pics[0]
    except Exception as e:result['error']=str(e)
    return result
if __name__=='__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        results=list(pool.map(download,json.loads((ROOT/'research.json').read_text())))
    (ROOT/'downloads.json').write_text(json.dumps(results,indent=2))
    for r in results:print(r['source'].split('/')[-1],len(r['files']),r.get('error',''))
