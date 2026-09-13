"""Control only the staged remote test server through its existing SSH tunnel."""
import json
from pathlib import Path
import re
import sys
import argparse
from rcon import command

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--deployment',type=Path,default=ROOT/'test-results/remote-current/deployment.json')
parser.add_argument('command',nargs='*')
args=parser.parse_args()
state=json.loads(args.deployment.read_text())
text=(Path(state['build'])/'server.cfg').read_text()
password=re.search(r'^set rcon_password "([^"\n]+)"$',text,re.M)[1]
result=command('127.0.0.1',state['rcon_local_port'],password,' '.join(args.command) or 'status')
print(json.dumps(result,indent=2))
raise SystemExit(1 if 'error' in result else 0)
