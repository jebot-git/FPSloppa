"""Cache user-requested visual references; references are not runtime assets."""
import requests,json,concurrent.futures
from pathlib import Path
from bs4 import BeautifulSoup
ROOT=Path(__file__).resolve().parent;OUT=ROOT/'research/style';OUT.mkdir(parents=True,exist_ok=True)
URLS={
'ut99':'https://www.artstation.com/projects/VJDQPg.json',
'quake':'https://www.artstation.com/projects/k426L6.json',
'librequake':'https://www.artstation.com/projects/X1G1rn.json',
'doom':'https://www.pngegg.com/ru/png-pdzzw',
'tribes':'https://api.sketchfab.com/v3/collections/52e293f1e5b049379dfefcacf7f186a0/models',
'cs':'https://gamebanana.com/apiv11/Wip/50324?_csvProperties=_sName,_sText,_aPreviewMedia'}
def get(item):
 k,u=item
 try:
  r=requests.get(u,timeout=35);r.raise_for_status();(OUT/(k+'.txt')).write_text(r.text);imgs=[]
  if k in ['ut99','quake','librequake']:
   j=r.json();imgs=[a['image_url'] for a in j.get('assets',[]) if a.get('image_url')];print(k,j.get('title'),j.get('description'),flush=True)
  elif k=='doom':
   s=BeautifulSoup(r.text,'html.parser');imgs=[a.get('content') for a in s.select('meta[property="og:image"]')]
  elif k=='tribes':
   for m in r.json().get('results',[]):
    print('TRIBES',m['name'],m['uid'],m.get('isDownloadable'),flush=True)
    imgs.append(max(m['thumbnails']['images'],key=lambda x:x['width'])['url'])
  elif k=='cs':
   j=r.json();print(k,j.get('_sName'),str(j.get('_sText',''))[:3000],flush=True)
   for a in j.get('_aPreviewMedia',{}).get('_aImages',[]):imgs.append(a['_sBaseUrl']+'/'+a['_sFile'])
  for i,u in enumerate(imgs):
   q=requests.get(u,timeout=30);q.raise_for_status();(OUT/(k+'-%02d.jpg'%i)).write_bytes(q.content)
  print(k,'IMAGES',len(imgs),flush=True)
 except Exception as e:print(k,type(e).__name__,str(e),flush=True)
if __name__=='__main__':
 with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:list(pool.map(get,URLS.items()))
