# FPSloppa 0.16v — server browser and master directory

Find dedicated servers from the desktop or VR menu, save favorites, and join a
match or spectate using the existing gameplay connection and asset-download flow.

- Added **Browse Servers** with live status, ping, search, mode/protocol filters,
  sorting, favorites, and Join/Spectate actions.
- Dedicated servers can expose a separate UDP query port and opt into authenticated
  master registration. Population displays distinguish humans, bots, spectators,
  pending downloads, and free human seats. Bots can yield their seats to players.
- Added a standalone Python master directory and credential-issuance tool. The
  master verifies query endpoints, bounds requests, and expires stale listings.
- Added `sv_master_test 1`: a dedicated server can start its own local test master
  and register automatically. Requires Python 3.10+; the child stops with the game.
- Direct joining and known favorites remain usable during master outages. Existing
  server configs keep discovery disabled until the operator enables it.

## Downloads and setup

Linux and Windows clients, Linux dedicated server, Quest APK, self-contained source,
and a small **Master-Server.zip** requiring Python 3.10+. Assets remain bundled;
Pico and retired asset/map-pack downloads remain excluded. The separate CQ
experimental branch is not part of this release.

No public master endpoint is preconfigured or deployed by this release. Operators
can host the supplied service and give players its HTTPS base URL. See the
[server browser setup guide](https://github.com/jebot-git/FPSloppa/blob/0.16v/docs/SERVER-BROWSER.md).
Public game servers still need reachable gameplay and query UDP ports, normally
7777 and 7779. The master provides discovery, not NAT traversal or gameplay relay.

Gameplay protocol remains `fpsloppa-39-rotating-koth`; use matching 0.16v packages
for the new discovery feature. Quest Android version code is 21.

## Validation

Validation covers the real dedicated-server/master/browser connection path,
spectator and player admission, bot-filled capacity, favorites, filters, master
outages, cookie replay rejection, TLS certificate/hostname checks, and simulated
VR controller interaction. Release package, archive, Linux startup, and Quest
signature/content audits are recorded in `docs/validation/release-0.16v.json`.

No fresh native Windows, physical headset, or public-WAN playtest is claimed.
Ping measures the query endpoint; gameplay access is confirmed when joining.
