# CQ live-test deployment

This branch now has a CQ-only service entrypoint: **81 districts, 128 admitted players, 16 reservations per district, UT99 weapons**. Lobby, voting, BSP/map uploads, alternate loadouts, alternate game modes and server-side bot population are disabled in the worker path and have no public protocol operations. The packaged executable rejects an ordinary arena-server launch. Client-supplied content is limited to validated, self-contained VRM files; map assets are installed by the operator. The normal branch and its protocol are not compatibility targets.

## VPS plan

These are **starting specifications for staged live tests**, inferred from local measurements, not certified requirements or a guarantee of 128-player combat. Keep every node in one datacenter on low-latency links. Prefer dedicated CPU resources: a shared vCPU's available compute varies with other tenants ([provider explanation](https://docs.hetzner.com/cloud/servers/faq/)). All services are Linux x86-64 and need no GPU. The supplied installer targets fresh Debian 12/13 or Ubuntu 24.04 VPSes.

| Compact full-atlas deployment | VPS count | Initial specification per VPS | Services |
|---|---:|---|---|
| Worker hosts | 3 | **8 dedicated vCPU, 16 GB RAM, 40 GB SSD, 1 Gbit/s** | 28 / 28 / 25 independent workers; seven regional gateways and seven console ENet facades per host |
| Master | 1 | **2 dedicated vCPU, 4 GB RAM, 40 GB NVMe/SSD, 1 Gbit/s** | Coordinator, SQLite player/campaign persistence, static HTML and VRM service |
| VPN ingress | 1 | **2 dedicated vCPU, 2 GB RAM, 10 GB SSD, 1 Gbit/s** | WireGuard client ingress and forwarding; no game simulation |
| **Total** | **5** | **28 dedicated vCPU, 54 GB RAM allocated** | 81 workers, 21 regional gateways, 21 ENet facades |

Use [`deploy/cq/compact.cfg`](../deploy/cq/compact.cfg) for this five-VPS plan. The default [`live.cfg`](../deploy/cq/live.cfg) spreads the same services across **seven worker hosts** (six with 12 districts, one with nine), one master and one VPN ingress: **nine VPSes**. Start those worker hosts at **8 dedicated vCPU / 8 GB / 40 GB / 1 Gbit/s**. This reduces each worker-host failure's map footprint from 25–28 districts to 9–12; it does not change the global player cap. Eight cores provide room for a hotspot containing most of the 128 players. Lowering a host to four cores is an experiment after measuring representative combat and scheduling latency, not the initial full-capacity recommendation.

For an isolated single-district worker trial, start at **2 dedicated vCPU / 2 GB RAM / 10 GB SSD**. That is a conservative deployment floor with OS and transport headroom; the measured worker process alone used about 140 MB. Several districts share one VPS, but each remains a separate process/map/authority. Buying 81 VPSes is unnecessary.

For coordinator failover testing, replace the single master with **three master VPSes**, each initially **2 dedicated vCPU / 8 GB RAM / 80 GB low-latency SSD**, running one etcd member and one coordinator frontend. That makes **seven VPSes** with the compact worker placement, or **eleven** with the seven-worker placement. Add two `[master NAME]` sections with unique private/public addresses; `prepare` generates quorum units and frontend lists automatically. The first master serves VRM and HTTP; those files/services still need backup or a separate storage failover arrangement. This is metadata/profile HA, not redundant VRM hosting or redundant VPN ingress.

etcd commit latency depends on storage and inter-node network latency, so use SSDs and a local quorum ([etcd hardware guidance](https://etcd.io/docs/v3.6/op-guide/hardware/)). Generated HA units set an 8 GiB backend quota, revision compaction and staggered hourly defragmentation. Full-state control revisions would otherwise accumulate quickly. Do not stretch the quorum across continents. The ingress is a single failure point in both supplied layouts.

## Measured basis and test limits

Measurements used an **Intel Core i7-12700**, actual baked campaign BSP workers, the console-only runtime and independently driven protocol clients. No server bots were involved. Four workers were online; one district held 16 moving/firing actors for 20 seconds. A separate phase drove 16 simultaneous ENet clients in the no-fire hub. These actors are test clients, not gameplay AI.

| Component | Idle CPU, cores | Populated TCP probe CPU, cores | RSS |
|---|---:|---:|---:|
| District worker | 0.014–0.016 | **0.26** for the populated district | **140–142 MiB** |
| Regional gateway | 0.018 | 0.109 | 28 MiB |
| Console ENet facade | 0.004 | 0.060 in the separate ENet phase | 68 MiB |
| Master | 0.012 | 0.014; 0.022 in the ENet phase | 31 MiB |

Compact CQ snapshots reduced the tested 16-player downstream application traffic from **174.5 to 44.9 Mbit/s**, about **74% less**; populated worker CPU fell from about 0.51 to 0.26 core. Snapshots retain presentation state; full private migration state is unchanged. Campaign-wide data is supplied by the slower status operation. Each packaged Godot process now uses a two-thread worker pool (five total threads observed), instead of allocating a pool based on the whole host's CPU count.

Eight equally busy 16-player districts extrapolate to roughly **360 Mbit/s of downstream application data**. Reserve at least **500–600 Mbit/s sustained headroom** for this workload after framing, VPN traffic, status and input traffic, and leave room for projectile-heavy fights. The master VRM service shares an 8 MB/s download budget across clients so avatar downloads cannot grow without bound. A 1 Gbit/s ingress is the initial floor; use 2.5 Gbit/s if the provider cannot sustain 1 Gbit/s or projectile/VRM traffic approaches the link limit. 360 Mbit/s sustained continuously is about **3.9 TB/day** of egress; a four-hour session at that rate is about **0.65 TB**, before overhead. Choose a transfer allowance accordingly.

The ENet phase completed 4,373 input/snapshot cycles with no errors, but p95 for the combined cycle was **69 ms locally**. The final transport/VRM regression measured 75 ms. These cycles include two operations and frame-driven forwarding; they are not ping measurements or proof of acceptable WAN latency. The desktop still uses snapshot smoothing, without the shipping client's prediction or VR tracking protocol. Ramp the live test **16 → 32 → 64 → 128**, with simultaneous gate transfers, respawns, projectile-heavy combat and VRM cache misses. Stop increasing load if authority expires, tick deadlines are missed, input latency grows or a gateway/ingress saturates. The 128-player admission test used synthetic workers; it is not a 128-player combat benchmark.

Results: [resource/ENet measurements](validation/cq-live-resources.json), [128-player admission](validation/cq-live-capacity.json), [etcd failover/profile transactions](validation/cq-live-ha.json), [trimmed deployment bundle test](validation/cq-live-package.json), [remote custom VRM validation](validation/cq-live-vrm.json) and [avatar screenshot](validation/cq-live-vrm.png). The trimmed per-host package was also tested with four real workers, VRM transfer and a returning Vulkan desktop client.

## Configure and deploy

1. Copy `deploy/cq/compact.cfg` or `deploy/cq/live.cfg` to a private location. Replace all documentation IP addresses and SSH accounts. Keep each complete region of four districts on one worker host. The final region contains only d80. The generator rejects missing/duplicate assignments and incomplete regions.
2. Permit SSH from your administration address and UDP 51820 between the listed hosts/testers at the provider firewall. Use fresh VPSes or reconcile existing host firewall policies with the generated rules. Clock synchronization is installed with chrony. Gameplay/control ports remain private on WireGuard.
3. Build the console CQ package, then prepare deployment files locally:

```sh
python3 tools/build_console_server.py --template Builds/Campaign81/FPSloppaServer.x86_64 --output Builds/CQLive --campaign-maps
./deploy/cq/deploy.sh prepare --cfg /private/cq/live.cfg --output /private/cq/generated --binary-dir Builds/CQLive
```

`prepare` never contacts the hosts. It creates per-host `config/node.cfg`, private cluster credentials, WireGuard keys/configs, systemd units and a trimmed server package, plus tester VPN/game profiles. The master receives the runtime for VRM validation and no maps; worker hosts receive only their assigned campaign maps and the manifests. Typical generated worker payloads were 140–174 MiB for 9–12 districts. Worker configs contain their own regional/worker credentials, not the master administration token. TCP etcd access is restricted to master IPs. Tester forwarding permits only ENet gameplay ports and the HTTP/VRM service, not private control endpoints.

Keep the output directory private and preserve `secrets.json`; rerunning `prepare` there reuses identities/keys. Do not commit or distribute the entire generated directory. Review `plan.json`, then deploy explicitly:

```sh
./deploy/cq/deploy.sh apply --output /private/cq/generated
# Or update only selected hosts:
./deploy/cq/deploy.sh apply --output /private/cq/generated --nodes w0 m0
```

`apply` uses existing SSH authentication and known-host checks. It installs packages/services with sudo, updates `/opt/fpsloppa-cq`, and retains `/var/lib/fpsloppa-cq`. It does not buy VPSes, configure provider firewalls or erase persistent data. These scripts have been generated and tested locally, including firewall syntax checks in an isolated network namespace; no remote hosts were provisioned for this change.

The resulting simple host configs look like [`master.cfg.example`](../deploy/cq/master.cfg.example) and [`workers.cfg.example`](../deploy/cq/workers.cfg.example). To run a prepared host manually, from its bundle directory:

```sh
python3 -m tools.district_cluster.service config/node.cfg
```

For local development, `./launch-conquest.sh --server` starts the campaign with the new `Builds/CQLive` runtime. `--districts d13 d40` runs only those workers while keeping the full campaign atlas. Existing pre-update local state directories may contain generated client/worker JSON with older settings; use a fresh test directory or update those generated files deliberately. Durable campaign databases and player profiles stay in the separate state directory.

Give each tester only their `clients/clientNNN.conf` and `.json`. Import the `.conf` into WireGuard, enable it, and launch:

```sh
./launch-conquest.sh /path/to/clientNNN.json
```

The master page is at `http://MASTER_PRIVATE_IP:8080/` over the VPN. The master also writes `/var/lib/fpsloppa-cq/www/index.html` every five seconds. It is a self-contained static file with a 30-second browser refresh, district control/capture/lockdown state, occupancy, UTC award time, scores and campaign history. It contains no player identifiers or credentials. An example is [the generated status page](validation/cq-live-status.html). For public publication, serve just this file with your static web server; never publish the state/config directory or private control port.

## Player and VRM persistence

The client saves a random identifier and 256-bit authentication secret on first use. Normal launches reuse that file; generated tester configs give each tester a separate file. The server stores only the secret hash. Knowing a public identifier cannot claim its profile. Preserve the client identity file when reinstalling or moving machines. The campaign identifier is stable independently of the access token.

Persistent data includes the stable actor ID, name, team, VRM hash, kills/deaths, last district preference, creation/last-seen timestamps, join count and generation. Returning clients cannot change their saved team or impersonate another ID by sending different join fields. Clean logout releases the live seat and archives the profile. Idle disconnected players release their seat after approximately 90–120 seconds; unresolved transfers retain reservations until recovery so a timeout cannot undo a committed handoff. Offline profiles consume no part of the 128-player cap.

Active profile data is durable in the control record. Offline profiles live in a separate SQLite `players` table or separate etcd keys, updated atomically with admission/logout. They do not enlarge every regional control document. Worker-owned counters checkpoint every five seconds and flush on death/respawn, logout and frozen handoff. A sudden worker loss can lose the latest uncheckpointed counter changes. Campaign resets preserve player profiles and lifetime counters. Exact transient movement, health, ammunition, velocity and timers are not a persistent saved life: a returning offline player enters normal reinforcement placement, preserving allied-first/neutral-fallback rules. Transfer journals remain responsible for in-flight handoff recovery.

Set `"vrm": "/absolute/path/avatar.vrm"` in the client JSON to upload/select a custom avatar. The server accepts only a self-contained binary VRM, at most 25 MB, after the existing humanoid/geometry/texture checks run in the console validator. It rejects external/data-URI resources, arbitrary files and other upload endpoints. Downloads verify SHA-256 and pass the client VRM validator too. Rendered VRMs are cosmetic and do not alter player collision. Downloads are limited to two per client at once; decoded model caching remains bounded. A red/blue indicator stays above custom avatars.

VRMs live under the master's persistent `vrm/` directory, with a 5 GB admission budget; full storage rejects new uploads rather than deleting referenced avatars. The first master owns this blob store even with metadata HA. Back up **the SQLite database with its live-backup API (or an etcd snapshot), the VRM directory, generated secrets, and clients' identity files**. Do not copy a live SQLite database without its WAL or a proper backup. Service updates preserve these paths.

## Verification

Thirty rule/profile/configuration tests pass. CQ disables unused peer-to-peer relay; the final 16-client connect/disconnect run completed without gateway errors. The runtime still reports small ObjectDB leak warnings at process shutdown. Live checks cover the 128-player limit, bounded district capacity, allied/neutral waiting deployment, real BSP workers, compact snapshots, 16 ENet clients, VRM validation/download, persistent rejoin, the Vulkan client and the trimmed per-host bundle. A real three-member etcd test verifies concurrent admission, profile authentication/archive transactions, one UTC award/reset, frontend/leader loss and mutation rejection without quorum.

```sh
python3 -m unittest tools.district_cluster.test_model tools.district_cluster.test_campaign tools.district_cluster.test_admission tools.district_cluster.test_profiles tools.district_cluster.test_deployment
python3 -m tools.district_cluster.live_deployment_test --output /tmp/fresh-cq-live-test --binary Builds/CQLive/FPSloppaServer.x86_64
python3 -m tools.district_cluster.campaign_capacity_test
python3 -m tools.district_cluster.ha_test --etcd /path/to/etcd --output /tmp/fresh-cq-ha-test
```

The CQ desktop now opens on a campaign menu with independent music/ambience controls. Use `"autoconnect": true` in client JSON to join immediately. See [CQ audio](CQ-AUDIO.md) for soundtrack sources, district mapping and combat transitions.
