"""Assemble only CQ worker assets, cfg examples and deployment entrypoints."""
import argparse,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SCRIPTS=['start-master.sh','start-workers.sh','start-local-cq.sh','set-moderator-password.sh','prepare-deployment.sh','deploy-components.sh']
def stage(source,destination):
    destination=destination.resolve();destination.mkdir(parents=True,exist_ok=True)
    for script in SCRIPTS:shutil.copy2(ROOT/script,destination/script)
    (destination/'tools/district_cluster/fixture_worker.py').unlink(missing_ok=True)
    for p in (ROOT/'tools/district_cluster').glob('*.py'):
        if p.name=='fixture_worker.py' or p.name.startswith(('test_','live_')) or p.name.endswith('_test.py'):continue
        target=destination/'tools/district_cluster'/p.name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
    for name in ['live.cfg','compact.cfg','deploy.sh']:
        target=destination/'deploy/cq'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/'deploy/cq'/name,target)
    files=['FPSloppaServer.x86_64','FPSloppaServer.pck','GODOT-LICENSE.txt','GODOT-COPYRIGHT.txt','ASSET_CREDITS.md','server-build.json','maps/CampaignDistricts/manifest.json']
    for pattern in ['licenses/**/*','maps/CampaignDistricts/district_*/district.bsp','maps/CampaignDistricts/district_*/collision.scn','maps/CampaignDistricts/district_*/navigation.res']:
        files += [p.relative_to(source).as_posix() for p in source.glob(pattern) if p.is_file()]
    for name in files:
        target=destination/'server'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source/name,target)
    # Worker boot reads this compatibility manifest, but never loads its old maps.
    target=destination/'server/maps/CQDistricts/manifest.json';target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/'maps/CQDistricts/manifest.json',target)
    for name in ['README.txt','Makkon_License.txt']:
        target=destination/'server/licenses/Makkon'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/'maps/Makkon'/name,target)
    for name in ['CQ-LIVE-DEPLOYMENT.md','CQ-MODERATION.md','CQ-CLIENT.md','CAMPAIGN-81.md']:
        target=destination/'docs'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/'docs'/name,target)
    (destination/'README.md').write_text('''# CQ experimental server deployment

Linux x86-64 console runtime; Python 3.11+; no GPU or client audio plugins.
81 maps, 128 players total, 16 per district. UT99/CQ only.

Quick local test (four workers plus their regional gateway/ENet facade):

```sh
./start-local-cq.sh --state-dir ./state --districts d40 d41 d42 d43
```

Open the generated absolute `state/client.json` with the client. Stop with Ctrl-C.
For the full atlas omit `--districts`; see docs for RAM/CPU requirements.

Multi-VPS test (edit IP addresses/accounts in a private copy first):

```sh
cp deploy/cq/compact.cfg /private/cq.cfg
./set-moderator-password.sh /private/cq.cfg
./prepare-deployment.sh --cfg /private/cq.cfg --output /private/generated
./deploy-components.sh --output /private/generated
```

Prepare is local-only. Apply installs the generated components over SSH.
Each generated host includes `install.sh`, `config/node.cfg` and its assets.
The workers supervisor starts regional gateways, ENet facades and district workers.
The master supervisor starts persistence, campaign control, static HTML and VRM validation.
For manual runs from a generated host folder, use `./start-master.sh` or
`./start-workers.sh`; both read `config/node.cfg`. Do not run these alongside systemd.
The ingress installer configures WireGuard and packet forwarding.

No passwords, player databases or deployment keys are included. Newcomers spawn
in the inner city; returning identities retain their last saved location when available.
Read docs/CQ-LIVE-DEPLOYMENT.md and docs/CQ-MODERATION.md before a remote test.
''')
    receipt_path=destination/'server/server-build.json';receipt=json.loads(receipt_path.read_text())
    receipt['package_files']=sorted(p.relative_to(destination/'server').as_posix() for p in (destination/'server').rglob('*') if p.is_file())
    receipt['package_scope']='CQ campaign workers and master VRM validation only'
    receipt_path.write_text(json.dumps(receipt,indent=2)+'\n')
    print('CQ_SERVER_STAGED',destination)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();stage(a.source,a.output)
