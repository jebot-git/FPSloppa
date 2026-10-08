"""Retry uncommon archive codecs with 7-Zip; extract to memory, never execute content."""
import json,subprocess,hashlib,time
from pathlib import Path
import attempt
HERE=attempt.HERE
original=attempt.members
def sevenzip(data):
 archive=attempt.LOCAL/(hashlib.sha256(data).hexdigest()+'.archive');archive.write_bytes(data)
 listing=subprocess.check_output(['7z','l','-slt',str(archive)],timeout=30,text=True)
 entries=listing.split('----------',1)[1].split('\n\n');files={};total=0
 for block in entries:
  fields=dict(line.split(' = ',1) for line in block.splitlines() if ' = ' in line)
  if not fields.get('Path') or fields.get('Folder')=='+':continue
  size=int(fields.get('Size','0'));total+=size
  if size>128*1024*1024 or total>512*1024*1024:raise ValueError('Archive extraction limit exceeded')
  b=subprocess.check_output(['7z','e','-so','-spd',str(archive),'--',fields['Path']],timeout=60,stderr=subprocess.DEVNULL)
  if len(b)!=size:raise ValueError('Archive member size mismatch')
  files[fields['Path']]=b
 return files
def unarchive(data):
 archive=attempt.LOCAL/(hashlib.sha256(data).hexdigest()+'.archive');archive.write_bytes(data)
 entries=json.loads(subprocess.check_output(['lsar','-j','-jss',str(archive)],timeout=30))['lsarContents'];files={};total=0
 for entry in entries:
  if entry.get('XADIsDirectory'):continue
  size=entry.get('XADFileSize',0);total+=size
  if size>128*1024*1024 or total>512*1024*1024:raise ValueError('Archive extraction limit exceeded')
  b=subprocess.check_output(['unar','-q','-o','-','-i',str(archive),str(entry['XADIndex'])],timeout=60,stderr=subprocess.DEVNULL)
  if len(b)!=size:raise ValueError('Unar member size mismatch')
  files[entry['XADFileName']]=b
 return files
def robust(data,depth=0):
 try:return original(data,depth)
 except Exception as error:
  if 'supported' not in str(error) and 'archive' not in str(error).lower():raise
  try:return sevenzip(data)
  except subprocess.CalledProcessError:return unarchive(data)
attempt.members=robust
while True:
 rows=json.loads((HERE/'attempts.json').read_text())
 if len(rows)==390:break
 time.sleep(10)
catalog={r['name']:r for r in json.loads((HERE/'downloads.json').read_text())}
for i,row in enumerate(rows):
 if row['status']=='unsupported':rows[i]=attempt.convert(catalog[row['name']])
(HERE/'attempts.tmp').write_text(json.dumps(rows,indent=2)+'\n');(HERE/'attempts.tmp').replace(HERE/'attempts.json')
print('Final converted',sum(r['status']=='geometry_converted_held' for r in rows),'of',len(rows),flush=True)
