# Server browser and master directory

The main menu's **BROWSE SERVERS…** opens an in-canvas browser shared by desktop
and VR. It supports search, mode and protocol filters, sorting by ping/humans/name,
favorites, **JOIN**, and **SPECTATE**. Existing direct-IP/hostname joining works
independently. No public master URL is bundled: operators must run a directory and
give players its HTTPS base URL, entered in the browser's **MASTER** field.

The browser reports humans, bots, free human seats, spectators, reserved downloads,
capacity, map, mode, effective weapon rules, build, and gameplay protocol. Bots can
yield their seats; spectators and accepted downloads occupy human seats. A bot-filled
server therefore remains joinable. A live full-server query disables both admission
buttons; the gameplay handshake always makes the final admission decision.

Ping is the round trip to the **query port**, excluding the cookie exchange. It is
not proof that the gameplay port is accessible. No query response leaves direct
joining available. Unknown-status favorites stay visible under the compatibility
filter; known mismatches cannot be joined. Refresh checks status once, with bounded
retries, rather than continually polling while a user is selecting a server.

## Dedicated-server setup

All new settings default to disabled/empty, preserving old configurations:

```cfg
set net_port "7777"
set sv_query_port "7779"
set sv_public "1"
set sv_master_url "https://master.example.com"
```

`master.example.com` is a placeholder for your deployment. The base URL may include
a path prefix if the reverse proxy strips it. Credentials, URL queries, fragments,
and redirects are not accepted. Numeric loopback HTTP URLs are allowed for local
setup, e.g. `http://127.0.0.1:8080`.

| Setting | Meaning |
|---|---|
| `sv_query_port` | `0` disables discovery; otherwise UDP 1024–65535, different from gameplay. Suggested port: 7779. |
| `sv_public` | `1` enables authenticated master heartbeats; requires a query port and master URL. |
| `sv_master_url` | HTTPS directory base URL, without `/v1/servers` or `/v1/heartbeat`. |
| `FPSLOPPA_MASTER_TOKEN` | Environment variable containing this server's issued registration token. Keep it out of `server.cfg` and launch arguments. |

Allow/forward **UDP 7777 and UDP 7779**, or your configured equivalents. RCON remains
separate TCP 7778 and is not used for discovery. Use `sv_public 0` with a nonzero
query port for manually added favorites without a directory. Manual favorites take
a numeric IPv4 or IPv6 address and separate game/query ports. Favorites and the
master URL persist in the existing client preferences (`--client-config` is honored).

The master derives the listed IP from the heartbeat source and probes that IP's
query port before publishing it. Gameplay and query external ports must match
their configured local ports; arbitrary external-address overrides and translated
external port numbers are not implemented. Public hosting still requires reachable
ports; this service does not provide NAT traversal, relays, or matchmaking.

Registration starts after successful dedicated startup. Successful heartbeats repeat
every 30–32 seconds; failures retry after 5, 10, 20, 40, then 60 seconds. HTTP work runs
asynchronously with a five-second timeout. A master outage neither stops the match
nor blocks direct joins. Logs include result/status codes, never credentials or
response bodies. Invalid opt-in settings, a missing token, or a query bind conflict
stop startup with a configuration error.

## Running a master

### Dedicated server doubling as a local test master

For a one-server experiment on the same computer, install Python 3.10+ and add:

```cfg
set sv_master_test "1"
set sv_master_test_port "8080"
```

Leave `sv_master_url` empty. This starts the bundled master helper as a child of
the dedicated server, enables queries on 7779 if no query port was configured,
and registers the game automatically using a fresh temporary credential. In the
client browser, enter **http://127.0.0.1:8080**. No token issuance or manual master
startup is needed. `FPSLOPPA_PYTHON` can select a Python executable when it is not
available as `python3` (`python` for a Windows source run).

The test directory binds only to IPv4 loopback and contains this game server.
Game/query listeners must include IPv4 loopback (`net_ip *`, `0.0.0.0`, or
`127.0.0.1`). This convenience mode is for local testing; use the standalone
HTTPS deployment below for other computers and multiple registered servers.
The child exits when the dedicated server closes, including after an abrupt
parent exit. Temporary token-digest/readiness files are removed. A bind conflict,
missing Python, or failed helper startup stops the dedicated launch clearly.
Ordinary dedicated hosting still requires no Python installation.

### Standalone service

The standalone implementation is `tools/master_server/server.py`, using Python's
standard library (Python 3.10+). It needs no Godot runtime or third-party packages.
Use one process per directory. The registry is in memory; a restart clears leases
and servers reappear on their next successful heartbeat. Capacity is 256 registered
server identities, with one operator-issued token per game server.

From the repository root, issue a credential without displaying the secret:

```sh
python3 tools/master_server/issue_token.py arena-1 \
  --tokens /path/to/master-tokens.json \
  --env-file /path/to/arena-1.env
```

The environment file is created with mode 0600. Transfer it privately to the
dedicated server and make it readable by its launching service. Keep the token
registry on the master; it contains SHA-256 digests, not usable bearer tokens.
For systemd, add `EnvironmentFile=/path/to/arena-1.env` to the dedicated service.
For a shell launch, use `set -a; . /path/to/arena-1.env; set +a` before starting it.
Restart services after changing credentials. To revoke a server, remove its ID
from the registry and restart the master, which also clears existing leases.
Issue a new ID/token/environment file to replace a credential.

The recommended deployment is a loopback listener behind an HTTPS reverse proxy:

```sh
python3 tools/master_server/server.py \
  --bind 127.0.0.1 --port 8080 \
  --tokens /path/to/master-tokens.json --trust-loopback-proxy
```

The proxy must **overwrite `X-Real-IP` with the immediate client's numeric source
IP**, forward `Authorization`, and preserve the request paths and bodies. Do not
copy a client-supplied forwarded header into `X-Real-IP`. Only a loopback bind can
enable proxy trust; keep that listener inaccessible remotely. Configure the HTTPS
proxy with a publicly trusted certificate and normal connection/body limits.

Alternatively, the service can terminate TLS directly:

```sh
python3 tools/master_server/server.py --bind 0.0.0.0 --port 8443 \
  --tokens /path/to/master-tokens.json \
  --cert /path/to/fullchain.pem --key /path/to/private-key.pem
```

A non-loopback bind requires TLS. Godot clients and advertisers validate the
certificate and hostname; untrusted/self-signed certificates fail. Install the OS
CA certificate package on the dedicated server. Direct TLS has no certificate hot
reload: restart it after renewal, or let the proxy handle TLS.

For a fully local experiment, use the loopback listener with `--allow-loopback`
and omit proxy trust, then configure `http://127.0.0.1:8080`. This explicit test
option permits loopback listings, not arbitrary private-network probes. Leave it
off for a public directory. IPv4 and IPv6 endpoint addresses are supported; one
registration ID represents one advertised endpoint at a time.

## Protocol and limits

`GET /v1/servers` returns `{ "schema": 1, "servers": [...] }`. Each row contains
the numeric address, game/query ports, ID, heartbeat age, and validated public
status. Entries expire 90 seconds after their last verified heartbeat. If the
directory is unavailable, the browser retains known endpoints in memory, marks
their status unverified, and queries them directly. Successful directory refreshes
remove expired public entries while retaining favorites.

`POST /v1/heartbeat` accepts only `{ "game_port": 7777, "query_port": 7779 }`,
with `Authorization: Bearer TOKEN`. The master retrieves status from the source
IP's UDP endpoint; it never trusts a body-supplied target IP or server metadata.
Failed verification does not renew the lease. Verification confirms only the
query endpoint, not player counts' honesty or gameplay reachability.

UDP uses bounded JSON with `wire: "fpsloppa-query-1"`. A client sends `hello`
with a random 16-byte hex nonce and 96 padding characters. The server returns
`challenge` with the nonce and an HMAC cookie bound to source IP/port, nonce, and
a ten-second clock bucket. A `status` request echoes that cookie and nonce; the
response carries the public `status` object. Current and previous buckets are
accepted. This protocol is separate from the unchanged ENet gameplay protocol.

Packets are limited to 1200 bytes. Challenges cannot be larger than their requests;
metadata requires a cookie. Server work is capped at 32 received packets/frame,
128 packets/second globally, and 16 packets/second/source IP. Browser queries use
eight concurrent sockets and one retry per stage, with cancellation on close/join.
The master bounds request bodies, simultaneous HTTP connections, per-source
requests, and per-token heartbeats. Public fields are allowlisted; player names,
chat, administration details, and downloaded assets do not enter the directory.

## Verification

```sh
python3 -m unittest discover -s tools/master_server -v
python3 deathmatch/tests/run_server_browser_tests.py
python3 deathmatch/tests/run_server_browser_tests.py \
  --server /path/to/fresh/FPSloppaServer.x86_64 --visual
python3 deathmatch/tests/run_discovery_tls_tests.py \
  --server /path/to/fresh/FPSloppaServer.x86_64
python3 deathmatch/tests/run_test_master_tests.py \
  --server /path/to/fresh/FPSloppaServer.x86_64
```

Tests use isolated temporary preferences, local sockets, and generated tokens.
Integration covers real registration, cookie queries, malformed requests, bot seats,
filters, saved favorites, 854×640 layout, spectator/player admission, and master
outage. `--visual` renders `test-results/server-browser/control-browser.png`.
The TLS test checks trusted, untrusted, and mismatched-hostname certificates in
the console-only runtime using a temporary certificate and local HTTPS listener.
Physical headset and WAN deployment validation remain separate.
