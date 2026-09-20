#!/usr/bin/env python3
"""Issue a registration token without printing it or using command arguments."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import secrets

from server import load_tokens


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("server_id")
    parser.add_argument("--tokens", type=Path, required=True)
    parser.add_argument("--env-file", type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[a-zA-Z0-9_-]{1,64}", args.server_id):
        parser.error("Use a server ID with 1–64 letters, digits, underscores or hyphens")
    rows = load_tokens(args.tokens) if args.tokens.exists() else {}
    if args.server_id in rows or len(rows) >= 256:
        parser.error("Server ID already registered or token limit reached")
    if args.env_file.exists() or args.env_file.resolve() == args.tokens.resolve():
        parser.error("Choose a new environment file distinct from the token registry")
    token = secrets.token_hex(32)
    descriptor = os.open(args.env_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as output:
        output.write("FPSLOPPA_MASTER_TOKEN=" + token + "\n")
    rows[args.server_id] = hashlib.sha256(token.encode()).hexdigest()
    args.tokens.write_text(json.dumps(rows, indent=2) + "\n")
    print("Registration created. Restart the master to load its token registry.")


if __name__ == "__main__":
    main()
