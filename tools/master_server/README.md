# FPSloppa master directory

Run a small public server directory for FPSloppa's **Browse Servers** menu.
Requires Python 3.10 or newer; no Godot runtime or third-party Python packages.

For games on the same host, enable a distinct `sv_query_port` on each game
(for example 7779 and 7789), then run:

```sh
python3 server.py
```

Open **http://127.0.0.1:8080/** for the live dashboard, or enter that base URL
in **Browse Servers**. Local discovery needs no token, `sv_public`, or master
URL on the games. Linux automatically detects bound UDP ports, including custom
query ports, in the master's network namespace. On other platforms, port 7779
is checked by default; add `--local-query-ports 7779 7789` for other ports.
Games with queries disabled (`sv_query_port 0`) cannot be discovered.

For public hosting, set `--local-address YOUR_PUBLIC_IP` so discovered games are
listed with the address players can reach. It defaults to the public bind IP,
otherwise loopback; it never changes where probes are sent. The query and gameplay
ports must be reachable at the advertised address. Use `--no-local-discovery` to
disable automatic listings. Local scans repeat every 10 seconds after the previous
scan finishes. Both local listings and authenticated registrations include the
version reported by the game and expire after 90 seconds without verification.

The bundled static dashboard shows versions, maps, rules, player/bot/spectator
counts, reserved and open seats, and status age. It refreshes every 10 seconds
and marks retained data when the directory is unavailable. Keep the `static/`
folder beside `server.py` when copying the service.

For games on other hosts, issue a token and start the service with its registry:

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

`--tokens` is optional and only enables authenticated registration from other
hosts. The dashboard and JSON API share the same HTTP/TLS listener.

The download includes [full setup and protocol documentation](docs/SERVER-BROWSER.md).
In the source checkout, the same guide is at [../../docs/SERVER-BROWSER.md](../../docs/SERVER-BROWSER.md).
No public endpoint or credentials are preconfigured. State is held in memory;
servers are discovered or register again after service restarts.
