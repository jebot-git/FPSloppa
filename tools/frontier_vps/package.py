"""Package the standalone CQ server; Godot is used only for an optional offline cook."""
import argparse,importlib.util
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
spec=importlib.util.spec_from_file_location('standalone_build',ROOT/'tools/build_standalone_server.py');build=importlib.util.module_from_spec(spec);spec.loader.exec_module(build)
build.package(ROOT/'native_server/build',ROOT/'native_server/cooked',a.output.resolve())
print('CQ_FRONTIER_NATIVE_PACKAGE',a.output.resolve())
