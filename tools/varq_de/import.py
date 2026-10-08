#!/usr/bin/env python3
"""Download the supplied Varq listing, attempt DE conversion, install only validated maps."""
import argparse,concurrent.futures,hashlib,json,re,subprocess,sys,urllib.request
from pathlib import Path
import libarchive
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;LOCAL=HERE/'local'
CATALOG='https://varq.net/cz/maps/counter-strike-1.6?option=1-2-3-4-42'
def fetch(url,path):
 if not path.exists():
  request=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'})
  with urllib.request.urlopen(request,timeout=60) as response:data=response.read(128_000_001)
  if len(data)>128_000_000:raise ValueError('Download exceeds budget')
  path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
 return path.read_bytes()
def obtain(name):
 folder=LOCAL/name;folder.mkdir(parents=True,exist_ok=True);url='https://varq.net/cz/maps/counter-strike-1.6/'+name
 row={'name':name,'page':url}
 try:
  html=fetch(url,folder/'page.html').decode();link=re.search(r'href="([^"<>]+\?download=[a-zA-Z0-9]+)"',html)
  if not link:raise ValueError('No archive download link')
  download='https://varq.net'+link[1];archive=folder/'source.archive';raw=fetch(download,archive)
  row.update(download=download,archive_sha256=hashlib.sha256(raw).hexdigest(),archive_bytes=len(raw),files=[])
  total=0
  with libarchive.file_reader(str(archive)) as entries:
   for entry in entries:
    path=entry.pathname;base=path.replace('\\','/').split('/')[-1]
    if Path(base).suffix.lower() not in ['.bsp','.wad','.txt']:continue
    if not entry.isfile:continue
    size=entry.size;total+=size
    if size>128_000_000 or total>256_000_000:raise ValueError('Unpacked archive exceeds budget')
    if not base or base in ['.','..'] or '\x00' in base:raise ValueError('Invalid archive entry')
    data=bytearray()
    for chunk in entry.get_blocks():
     data.extend(chunk)
     if len(data)>128_000_000:raise ValueError('Extracted entry exceeds budget')
    dest=folder/('notices' if Path(base).suffix.lower()=='.txt' else 'assets')/((hashlib.sha256(path.encode()).hexdigest()[:8]+'_' if Path(base).suffix.lower()=='.txt' else '')+base.lower());dest.parent.mkdir(exist_ok=True)
    if dest.exists() and dest.read_bytes()!=data:raise ValueError('Conflicting archive basenames')
    dest.write_bytes(data);row['files'].append({'archive_path':path,'name':dest.name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
  if not (folder/'assets'/(name+'.bsp')).exists():raise ValueError('Named BSP absent from archive')
  row['status']='downloaded'
 except Exception as e:row.update(status='download_failed',error=str(e))
 print(name,row['status'],flush=True);return row

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',default='godot');p.add_argument('--fetch-only',action='store_true');p.add_argument('--map');a=p.parse_args();LOCAL.mkdir(exist_ok=True)
 html=fetch(CATALOG,LOCAL/'catalog.html').decode();names=list(dict.fromkeys(re.findall(r'href="/cz/maps/counter-strike-1\.6/(de_[a-zA-Z0-9_-]+)"',html)))
 if a.map:names=[n for n in names if n==a.map]
 if not names:raise ValueError('No map entries found')
 receipt=HERE/'sources.json'
 existing=json.loads(receipt.read_text()) if receipt.exists() else {'catalog':CATALOG,'maps':[]}
 with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:rows=list(pool.map(obtain,names))
 keep=[r for r in existing['maps'] if r['name'] not in names];existing['maps']=keep+rows;receipt.write_text(json.dumps(existing,indent=2)+'\n')
 if a.fetch_only:return
 results=[]
 retired=set(json.loads((ROOT/"deathmatch/maps/retired.json").read_text()))
 for row in rows:
  name=row['name'];folder=LOCAL/name;result={'name':name,'source_status':row['status']}
  if 'de_varq_'+name[3:] in retired:
   print(name,'retired; skipped',flush=True);continue
  if row['status']=='downloaded':
   out=folder/'converted';out.mkdir(exist_ok=True)
   command=[sys.executable,str(ROOT/'tools/cs16_map_converter/convert.py'),str(folder/'assets'/(name+'.bsp')),'--wad-dir',str(folder/'assets'),'--replace-missing','--output',str(out),'--validate','--godot',a.godot]
   with (folder/'conversion.log').open('w') as log:
    try:code=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=360).returncode
    except subprocess.TimeoutExpired:code=124
   report=out/(name+'_fps.conversion.json');data=json.loads(report.read_text()) if report.exists() else {}
   result.update(status='validated' if code==0 and data.get('runtime_validation')=='passed' else 'not_installed',exit_code=code,diagnostic=(folder/'conversion.log').read_text()[-2000:].replace(str(ROOT),'.'))
   validation=out/(name+'_fps.validation.log')
   if validation.exists():
    lines=validation.read_text().splitlines();result['runtime_checks']=sum(line.startswith('PASS ') for line in lines);result['validation_failures']=[line for line in lines if line.startswith('FAIL ') or 'ERROR:' in line]
   if data:result.update(sha256=data['sha256'],bytes=data['bytes'],warnings=data['warnings'],replaced_textures=sum(t['source'].startswith('generated:') for t in data['textures']),spawns=[len(x) for x in data['layout']['starts']],sites=data['layout']['sites'])
   if result['status']=='validated':
    dest=ROOT/'maps'/('de_varq_'+name[3:]+'.bsp');raw=(out/(name+'_fps.bsp')).read_bytes()
    if dest.exists() and dest.read_bytes()!=raw:raise ValueError('Refusing to overwrite different installed map '+str(dest))
    dest.write_bytes(raw);result['installed']=str(dest.relative_to(ROOT))
  else:result.update(status='not_installed',diagnostic=row.get('error',''))
  results.append(result);print(name,result['status'],flush=True)
  path=HERE/'results.json';previous=json.loads(path.read_text()) if path.exists() else {'maps':[]};previous.pop('summary',None);previous['maps']=[r for r in previous['maps'] if r['name'] not in [v['name'] for v in results]]+results;path.write_text(json.dumps(previous,indent=2)+'\n')
if __name__=='__main__':main()
