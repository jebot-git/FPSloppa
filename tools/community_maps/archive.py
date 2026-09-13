"""Download review candidates and read ZIP members with the system unzip program."""
from pathlib import Path, PurePosixPath
import argparse
import concurrent.futures
import hashlib
import json
import re
import subprocess

LOCAL = Path(__file__).with_name('local')
INDEX = 'https://www.quaddicted.com/files/maps/multiplayer/'


def members(path):
    return subprocess.check_output(['unzip', '-Z1', str(path)], text=True).splitlines()


def read_member(path, member):
    # unzip -p writes no archive-supplied path to disk; callers choose output paths.
    assert member in members(path) and not any(c in member for c in '*?[')
    return subprocess.check_output(['unzip', '-p', str(path), member])


def review(name, section=''):
    assert re.fullmatch(r'[a-zA-Z0-9_-]+', name)
    assert section in ['', 'tf', 'ctf']
    label=(section+'-' if section else '')+name
    url=INDEX+(section+'/' if section else '')+name+'.zip'
    path = LOCAL / ('quaddicted-' + label + '.zip')
    if not path.exists():
        part = path.with_suffix('.zip.part')
        subprocess.run(['curl', '-fLsS', '--max-time', '90', '--retry', '2', url, '-o', str(part)], check=True)
        subprocess.run(['unzip', '-tqq', str(part)], check=True)
        part.replace(path)
    listing = members(path)
    text = ''
    for member in listing:
        if PurePosixPath(member).suffix.lower() in ['.txt', '.md']:
            text += '\nFILE ' + member + '\n' + read_member(path, member).decode('utf-8', errors='replace')
    (LOCAL / (label + '-review.txt')).write_text(text)
    result = dict(id=label, source=url, archive_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), members=listing)
    (LOCAL / (label + '-archive.json')).write_text(json.dumps(result, indent=2)+'\n')
    return name, len(text), 'documentation bytes'


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('names', nargs='+')
    parser.add_argument('--section',choices=['tf','ctf'],default='')
    args = parser.parse_args()
    LOCAL.mkdir(exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for row in pool.map(lambda name:review(name,args.section), args.names):
            print(*row, flush=True)
