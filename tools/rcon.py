"""Password-authenticated FPSloppa RCON client (TCP; commands are not encrypted)."""
import argparse
import getpass
import hashlib
import hmac
import json
import os
import socket


def command(host, port, password, text):
    with socket.create_connection((host, port), timeout=8) as sock:
        stream = sock.makefile('rb')
        challenge = json.loads(stream.readline(4097))
        nonce = challenge['nonce']
        if challenge.get('protocol') != 'fpsloppa-rcon-1' or len(nonce) != 64:
            raise ValueError('Unexpected RCON handshake')
        sign = lambda text: hmac.new(password.encode(), text.encode(), hashlib.sha256).hexdigest()
        request = {'command': text, 'mac': sign(nonce + '\n' + text)}
        sock.sendall((json.dumps(request) + '\n').encode())
        response = json.loads(stream.readline(65537))
        payload = response['result']
        if not hmac.compare_digest(sign(nonce + '\nresponse\n' + payload), response['mac']):
            raise ValueError('Response authentication failed (wrong password or modified response)')
        return json.loads(payload)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('host')
    parser.add_argument('command', nargs='+')
    parser.add_argument('--port', type=int, default=7778)
    args = parser.parse_args()
    password = os.environ.get('FPSLOPPA_RCON_PASSWORD') or getpass.getpass('RCON password: ')
    result = command(args.host, args.port, password, ' '.join(args.command))
    print(json.dumps(result, indent=2))
    return 1 if 'error' in result else 0


if __name__ == '__main__':
    raise SystemExit(main())
