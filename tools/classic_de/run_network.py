"""Run current converted-cover ENet regression; legacy Nuke has been retired."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).resolve().parents[1]/'de_penetration/network.py'),run_name='__main__')
