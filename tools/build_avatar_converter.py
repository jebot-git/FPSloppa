#!/usr/bin/env python3
"""Forward to the independently maintained AvatarConverter repository."""
import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__, add_help=False)
    parser.add_argument('--checkout', type=Path, default=ROOT / 'external-tools/AvatarConverter')
    args, forwarded = parser.parse_known_args()
    checkout = args.checkout.expanduser().resolve()
    script = checkout / 'tools/build.py'
    if not script.is_file():
        raise SystemExit('Clone https://github.com/jebot-git/AvatarConverter.git into external-tools/AvatarConverter, '
                         'or pass --checkout /path/AvatarConverter. See https://github.com/jebot-git/AvatarConverter/releases/tag/v0.1.0 for portable binaries.')
    return subprocess.call([sys.executable, str(script), *forwarded], cwd=checkout)

if __name__ == '__main__':
    raise SystemExit(main())
