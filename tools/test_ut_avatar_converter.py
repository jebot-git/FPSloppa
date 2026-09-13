#!/usr/bin/env python3
"""Forward to the independently maintained UTAvatarConverter repository."""
import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__, add_help=False)
    parser.add_argument('--checkout', type=Path, default=ROOT / 'external-tools/UTAvatarConverter')
    args, forwarded = parser.parse_known_args()
    checkout = args.checkout.expanduser().resolve()
    script = checkout / 'tools/test.py'
    if not script.is_file():
        raise SystemExit('Clone https://github.com/jebot-git/UTAvatarConverter.git into external-tools/UTAvatarConverter, '
                         'or pass --checkout /path/UTAvatarConverter. See https://github.com/jebot-git/UTAvatarConverter/releases/tag/v0.1.0 for portable binaries.')
    return subprocess.call([sys.executable, str(script), *forwarded], cwd=checkout)

if __name__ == '__main__':
    raise SystemExit(main())
