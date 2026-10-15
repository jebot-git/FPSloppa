#!/usr/bin/env python3
"""Copy a plain v4 deployment PCK, replacing only explicitly supplied files."""
import argparse,hashlib,json,shutil,struct
from pathlib import Path


def entries(source):
    header=source.read(128)
    if header[:4]!=b'GDPC' or struct.unpack_from('<I',header,4)[0]!=4:raise ValueError('Expected Godot PCK v4')
    if struct.unpack_from('<I',header,20)[0]!=2:raise ValueError('Expected unencrypted directory-at-end PCK')
    base,directory=struct.unpack_from('<QQ',header,24);source.seek(directory)
    count=struct.unpack('<I',source.read(4))[0];rows=[]
    for _ in range(count):
        n=struct.unpack('<I',source.read(4))[0];path=source.read(n)
        offset,size=struct.unpack('<QQ',source.read(16));digest=source.read(16);flags=source.read(4)
        if flags!=b'\0'*4:raise ValueError('Encrypted/removal entries unsupported')
        rows.append([path,offset,size,digest,flags])
    return header,base,directory,rows


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--overrides',type=Path,required=True);a=p.parse_args()
    replacements={f.relative_to(a.overrides).as_posix():f.read_bytes() for f in a.overrides.rglob('*') if f.is_file()}
    with a.source.open('rb') as source,a.output.open('xb') as target:
        header,base,directory,rows=entries(source);known={r[0].rstrip(b'\0').decode() for r in rows}
        missing=set(replacements)-known
        if missing:raise ValueError('Cannot add unregistered entries: '+repr(missing))
        source.seek(0);remaining=directory
        while remaining:
            block=source.read(min(8*1024*1024,remaining));target.write(block);remaining-=len(block)
        for row in rows:
            name=row[0].rstrip(b'\0').decode()
            if name in replacements:
                target.write(b'\0'*((-target.tell())%16));data=replacements[name]
                row[1]=target.tell()-base;row[2]=len(data);row[3]=hashlib.md5(data).digest();target.write(data)
        target.write(b'\0'*((-target.tell())%16));new_directory=target.tell();target.write(struct.pack('<I',len(rows)))
        for path,offset,size,digest,flags in rows:target.write(struct.pack('<I',len(path))+path+struct.pack('<QQ',offset,size)+digest+flags)
        target.seek(32);target.write(struct.pack('<Q',new_directory))
    a.output.with_suffix('.patch.json').write_text(json.dumps({'source':str(a.source),'source_sha256':hashlib.sha256(a.source.read_bytes()).hexdigest(),'output_sha256':hashlib.sha256(a.output.read_bytes()).hexdigest(),'overrides':{name:hashlib.sha256(data).hexdigest() for name,data in replacements.items()}},indent=2))

if __name__=='__main__':main()
