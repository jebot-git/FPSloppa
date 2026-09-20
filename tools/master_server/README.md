# FPSloppa master directory

Run a small public server directory for FPSloppa's **Browse Servers** menu.
Requires Python 3.10 or newer; no Godot runtime or third-party Python packages.

In this directory, issue a token and start a local test service:

```sh
python3 issue_token.py arena-1 --tokens /path/to/tokens.json --env-file /path/to/arena-1.env
python3 server.py --tokens /path/to/tokens.json --allow-loopback
```

This listens on `http://127.0.0.1:8080` and explicitly allows local test listings.
The environment file contains the dedicated server's private registration token;
the master registry stores only its SHA-256 digest. Neither is included here.

For Internet use, omit `--allow-loopback`. Place the loopback listener behind an
HTTPS reverse proxy using `--trust-loopback-proxy`, or provide `--cert` and `--key`
with a public bind. When proxy trust is enabled, the proxy must overwrite
`X-Real-IP` with the immediate client's IP address. See `python3 server.py --help`.

Configure the dedicated server with `sv_query_port`, `sv_public`, `sv_master_url`,
and the `FPSLOPPA_MASTER_TOKEN` environment variable. Give players the master base
URL to enter in their browser. The service does not relay gameplay or open NAT ports.

The download includes [full setup and protocol documentation](docs/SERVER-BROWSER.md).
In the source checkout, the same guide is at [../../docs/SERVER-BROWSER.md](../../docs/SERVER-BROWSER.md).
No public endpoint or credentials are preconfigured. State is held in memory;
servers register again after service restarts, and leases expire after 90 seconds.
