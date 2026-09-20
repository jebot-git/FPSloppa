# Independent BSP29 districts

This opt-in CQ experiment replaces the single Vesper city BSP with sixteen independently compiled, sealed BSP29 maps. Each remains a 250 × 250 metre district of the same 1 km², 4 × 4 city. It is implemented on `experimental/cq-districts`; main and the default whole-city CQ profile are unchanged.

Each worker instantiates only its assigned collision map and local navigation mesh. The master loads the atlas metadata, actors and match rules, with **no district geometry**. Clients instantiate one district scene and may retain one prefetched destination scene. This removes the need to fit the sum of all districts into one BSP29 file, without raising any individual file's limits.

## Environment and layout

The original sixteen district themes, origins, team territories, four spawns per district and corner-homebase equipment rules are preserved. Each district now contains four furnished halls with ground, 8 m and 16 m galleries, a 24 m exterior roof gallery, switchback ramps, balcony doors, four elevated connecting bridges, covered street alcoves and its themed central plaza. Cathedral ribs, tombs, consoles, storage, machinery, reactor structures, gardens and orbital holograms vary with the district theme. A shared material palette, street axes, night sky and gate dimensions keep adjoining districts coherent.

There are 14,996 structural/detail brushes across the pack. All maps received full VIS and RGB night lighting with 16-unit lightmap spacing, bounce and dirt. Their 2,608 bake emitters are not runtime point lights. Opaque walk-through holographic gates conceal the unloaded districts. The existing weapon/avatar illumination limit remains two effects, including on VR; translated BSP occlusion planes preserve wall blocking.

Maps use local coordinates, bounded by ±137 m horizontally including hidden gate continuations, and −3 to 112 m vertically. Runtime scenes are translated to the original city coordinates. The public play area ends at ±125 m. Gates align at 24 m wide and 16 m high; ordinary transfer is accepted only through the matching neighboring opening. The importer omits sky triangles, so matching client/worker collision caps close the space above the 36 m boundary walls and at the sky ceiling.

## File budgets

The generator asserts format 29, disallows BSP2 promotion and checks engine/import budgets. Measurements for the committed pack:

| Resource | Smallest district | Largest district | All districts |
|---|---:|---:|---:|
| BSP bytes | 7,717,072 | 11,799,400 | 161,428,544 |
| Vertices | 14,758 | 15,909 | 246,006 |
| Faces | 10,401 | 11,284 | 173,804 |
| Nodes | 7,024 | 7,869 | 119,100 |
| Leaves | 4,310 | 4,698 | 71,705 |
| Marksurfaces | 15,443 | 17,432 | 261,476 |

Checks require vertices/faces/marksurfaces below 65,535, nodes/leaves/clipnodes below 32,767 and each BSP below FPSloppa's 25,000,000-byte import limit. Collision uses render triangles, so these builds use `-noclip`. BSPX RGB lighting supplements the version-29 geometry. This is a FPSloppa map pack, not a claim of unmodified Quake-engine gameplay compatibility. See the compiler's [format options](https://ericw-tools.readthedocs.io/en/latest/qbsp.html) and [limit-check history](https://ericw-tools.readthedocs.io/en/latest/changelog.html).

## Authority and handoff

The SHA-256 of `maps/CQDistricts/manifest.json` identifies the atlas. It binds every district's BSP, collision, presentation and navigation hashes. Workers validate their own server assets; clients validate all sixteen client assets at startup. The master checks the atlas identity and the assigned district BSP hash in each worker greeting. The public protocol is `fpsloppa-cq-experimental-3-cq-district-bsp-1`, incompatible with ordinary CQ clients. Map downloads during connection are not implemented: install the matching pack beforehand.

Client prefetch starts within 40 m of a gate. A transition freezes input, instantiates the destination, synchronizes collision, then acknowledges readiness for the generation-bound authoritative baseline. Global position, orientation and velocity remain in the same city coordinate system. Old-generation packets cannot resume prediction. The hidden corridor behind each gate provides room for handoff.

Workers evaluate capture-circle height, range and line of sight using their own geometry. The master uses that presence result to advance capture and match time. Spawn and pickup metadata remain global so a worker can construct a master-authorized remote respawn before transferring the actor; loading other districts' geometry is unnecessary. Bots navigate locally and target the next adjacent gate when pursuing an objective in another district.

The 64-player global limit, 16 reserved slots per district, gate closures, nearest-friendly respawns and private reinforcement waiting rooms remain in force. Projectiles terminate on district exit; cross-district shooting, collision and visibility are not supported.

## Launch

From this experimental worktree, with Godot available:

```sh
./launch-conquest-district-maps.sh --server
./launch-conquest-district-maps.sh 127.0.0.1
```

The first command runs a master that launches local worker processes on demand, up to sixteen. The second starts a matching client on port 7787. The supplied configuration keeps ordinary server limits separate.

For independently supervised instances, build a console package:

```sh
python3 tools/build_console_server.py --template /path/to/console-template \
  --cq-district-maps --output Builds/CQDistrictMaps
python3 tools/cq_gateway/external_config.py --output /private/new-cq-session
```

Run the master with `--experimental-cq --cq-district-maps --config /path/to/conquest-district-maps.cfg --cq-external-workers /private/new-cq-session/master.json`. Run each worker with `--experimental-cq --cq-district-maps --cq-worker N --worker-session-file /private/new-cq-session/worker-N.json`. All sixteen inventory workers must start within the startup deadline. Use the private loopback/SSH-tunnel setup in [CQ-MULTI-SERVER.md](CQ-MULTI-SERVER.md) for separate machines; the public gameplay connection remains through the master.

The server package carries the full atlas and server asset pack for convenient assignment, but each worker loads only its own map. Legacy CQ assets remain packaged for the default profile. File distribution size is not a measurement of resident memory.

## Rebuild and validation

```sh
python3 tools/cq_maps/build.py --compiler /path/to/ericw-tools/bin
for district in $(seq 0 15); do
  godot --headless --xr-mode off --path . \
    --script tools/cq_maps/prepare.gd -- "$district" || exit
done
python3 tools/cq_maps/manifest.py
godot --headless --xr-mode off --path . --script tools/cq_maps/verify.gd
python3 tools/cq_maps/bots.py
python3 tools/cq_gateway/external_test.py \
  --binary Builds/CQDistrictMaps/FPSloppaServer.x86_64 \
  --district-maps --latency-ms 30 --name district-maps-network --respawn --failure
python3 tools/cq_gateway/waiting_test.py \
  --binary Builds/CQDistrictMaps/FPSloppaServer.x86_64 --district-maps --direct-respawn
python3 tools/cq_gateway/waiting_test.py \
  --binary Builds/CQDistrictMaps/FPSloppaServer.x86_64 --district-maps
```

Preparation checks every spawn, pickup, hall level, ramp endpoint and gate route: 880 navigation points and 144 gate-clearance rays. Geometry verification additionally checks translated floors/contents, portal rejection, sky containment, complete light atlases and translated illumination occlusion. Desktop views of cathedral, foundry, observatory, market, garden and dock districts were rendered; representative interiors, plazas and aerial views were inspected using OpenGL compatibility on Intel Arc A770.

Two local ENet clients with four independently started console workers passed map transfers, prediction, respawn, stale-generation rejection, round reset and expected whole-session shutdown on worker loss with 30 ms added private-link RTT. Separate live fixtures passed immediate remote respawn and automatic deployment from a full-capacity waiting room. A sixteen-worker smoke run populated all districts with 64 bots, verified movement by every bot, transfers, occupancy limits and one map per worker/zero on the master. Results and package hashes are in [the validation receipt](validation/cq-district-maps.json).

This is not a 64-human-client, headset, full-match balance or physical multi-host performance certification. In the two-client run, gate pauses were 128–193 ms, despite prefetched scene activation around 22–23 ms. Opaque gates conceal the scene swap but do not eliminate the authority-handshake pause. The master remains a serialization/bandwidth bottleneck and a single point of failure; district splitting does not increase the configured player or district counts. Existing ObjectDB/resource-in-use warnings remain during some test shutdowns.
