"""Fetch selected archives with archive SHA-1 verification; never execute content."""
import concurrent.futures,hashlib,html,json,re,subprocess
from pathlib import Path
from catalog import HERE,LOCAL,get,plain

def fetch(row):
 out=dict(row)
 try:
  page=get(row['page'])
  labels={plain(k):plain(v) for k,v in re.findall(r'<label>(.*?)</label>\s*<span[^>]*>(.*?)</span>',page,re.S)}
  sha=labels['SHA1 Hash'].lower();assert re.fullmatch('[0-9a-f]{40}',sha)
  out.update(archive=labels['File Name'],archive_sha1=sha)
  section=page.split('Download Mirrors',1)[1].split('</ul>',1)[0]
  urls=[html.unescape(x) for x in re.findall('href="(https://[^"]+)"',section)]
  dest=LOCAL/'archives'/sha;dest.parent.mkdir(exist_ok=True)
  errors=[]
  for url in urls:
   if dest.exists() and hashlib.sha1(dest.read_bytes()).hexdigest()==sha:break
   temp=dest.with_suffix('.part')
   run=subprocess.run(['curl','-fLsS','--max-time','120','--max-filesize','268435456',url,'-o',str(temp)],capture_output=True)
   if run.returncode==0 and hashlib.sha1(temp.read_bytes()).hexdigest()==sha:
    temp.replace(dest);break
   errors.append(url+': '+run.stderr.decode(errors='replace')[-160:]);temp.unlink(missing_ok=True)
  if not dest.exists():raise ValueError('No verified mirror: '+'; '.join(errors))
  out.update(status='downloaded',bytes=dest.stat().st_size)
 except Exception as e:out.update(status='download_failed',error=str(e))
 print(out['name'],out['status'],flush=True)
 return out

def main():
 rows=[r for r in json.loads((HERE/'catalog.json').read_text()) if r['eligible']]
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
  result=[]
  for row in pool.map(fetch,rows):
   result.append(row);(HERE/'downloads.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
