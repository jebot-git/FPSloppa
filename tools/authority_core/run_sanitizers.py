#!/usr/bin/env python3
"""Compile the host-independent authority with ASan/UBSan in the portable toolchain."""
import argparse, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--golden',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
code='''import glob,subprocess
files=glob.glob('/src/addons/fps_native/src/authority_*.cpp')
files.remove('/src/addons/fps_native/src/authority_world.cpp')
files+=glob.glob('/src/tools/authority_core/*tests.cpp')
subprocess.run(['g++','-std=c++17','-O1','-g1','-ffp-contract=off','-fsanitize=address,undefined','-fno-omit-frame-pointer','-I/src/addons/fps_native/src',*files,'-o','/results/authority-tests'],check=True)
subprocess.run(['/results/authority-tests','/golden'],check=True)
'''
with (out/'sanitizers.log').open('w') as log:
 subprocess.run(['podman','run','--rm','--entrypoint','python3','-v',f'{ROOT}:/src:ro','-v',f'{a.golden.resolve()}:/golden:ro','-v',f'{out}:/results','localhost/fpsloppa-server-toolchain:godot-4.7.2-jammy','-c',code],stdout=log,stderr=subprocess.STDOUT,check=True)
print((out/'sanitizers.log').read_text())
