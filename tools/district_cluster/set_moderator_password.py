"""Configure a master/inventory .cfg via hidden prompt; never store plaintext."""
import argparse,configparser,getpass,os,tempfile
from pathlib import Path
from .moderation import verifier

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('cfg',type=Path);p.add_argument('--disable',action='store_true');a=p.parse_args()
    c=configparser.ConfigParser(interpolation=None);c.read(a.cfg)
    section='cluster' if c.has_section('cluster') else 'cq'
    if section=='cq' and c[section].get('role')!='master':raise SystemExit('Password belongs only in a master cfg or deployment inventory')
    if not a.disable:
        password=getpass.getpass('New moderator password: ')
        if password!=getpass.getpass('Repeat password: '):raise SystemExit('Passwords differ')
        value=verifier(password)
    else:value=''
    c[section]['moderator_password_hash']=value
    with tempfile.NamedTemporaryFile(mode='w',dir=a.cfg.parent,delete=False) as f:
        os.chmod(f.name,0o600);c.write(f);name=f.name
    os.replace(name,a.cfg)
    print('Moderator configuration updated. Redeploy/restart every master to activate and invalidate old sessions.')
if __name__=='__main__':main()
