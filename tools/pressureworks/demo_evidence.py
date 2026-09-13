"""Summarise public MVD framing and flag announcements, without exposing userinfo.

This is not a full Quake network-protocol decoder or a spatial replay reader.
Framing follows ezQuake src/cl_demo.c (dem_read/set/multiple/single/stats/all).
"""
import argparse, gzip, hashlib, json, re, struct
from pathlib import Path


def analyse(path):
    compressed=path.read_bytes();data=gzip.decompress(compressed)
    offset=0;milliseconds=0;packets=0;captures=[]
    while offset<len(data):
        if offset+2>len(data):raise ValueError('Truncated demo header')
        delta,kind=data[offset:offset+2];offset+=2;milliseconds+=delta;kind&=7
        if kind==2:
            if offset+8>len(data):raise ValueError('Truncated sequence message')
            offset+=8;continue
        if kind==3:offset+=4
        if kind not in (1,3,4,5,6):raise ValueError('Unsupported demo message')
        size=struct.unpack_from('<I',data,offset)[0];offset+=4
        if size>100000 or offset+size>len(data):raise ValueError('Invalid message length')
        message=bytes(c&127 for c in data[offset:offset+size]);offset+=size;packets+=1
        for match in re.finditer(rb'captured the (Red|Blue) flag!\n',message):
            seconds=milliseconds/1000;flag=match[1].decode()
            if not any(abs(row['seconds']-seconds)<.2 and row['flag']==flag for row in captures):
                captures.append({'seconds':seconds,'flag':flag})
    return {'sha256':hashlib.sha256(compressed).hexdigest(),'duration_seconds':milliseconds/1000,
            'packets':packets,'capture_announcements':captures,
            'note':'MVD framing validated to EOF. Embedded capture announcements deduplicated within 0.2s; not a complete protocol decoder or spatial replay.'}


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('demo',type=Path);p.add_argument('output',type=Path);p.add_argument('--source',required=True);a=p.parse_args()
    result={'source':a.source,**analyse(a.demo)};a.output.write_text(json.dumps(result,indent=2)+'\n')
