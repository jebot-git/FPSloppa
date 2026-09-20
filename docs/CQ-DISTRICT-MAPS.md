# Independent BSP29 districts

This opt-in CQ experiment replaces the single Vesper city BSP with sixteen independently compiled, sealed BSP29 maps. Each remains a 250 × 250 metre district of the same 1 km², 4 × 4 city. It is implemented on `experimental/cq-districts`; main and the default whole-city CQ profile are unchanged.

Each worker instantiates only its assigned collision map and local navigation mesh. The master loads the atlas metadata, actors and match rules, with **no district geometry**. Clients instantiate one district scene and may retain one prefetched destination scene. This removes the need to fit the sum of all districts into one BSP29 file, without raising any individual file's limits.

## Environment and layout

The original sixteen district themes, origins, team territories, four spawns per district and corner-homebase equipment rules are preserved. **Revision 3 is the enclosed-city experiment.** It retains sixteen individually authored street networks, with offset junctions, switchbacks, service loops, market lanes and processional streets that differ even after rotation or reflection. Solid interblocks now occupy the former open gaps, surrounding a connected network of indoor streets, access passages and multilevel halls.

The carriageway is **7 m wide**, with 2 m sidewalks; parked vehicles occupy separate bays. Windows, shop fronts, stalls, lamps and chamfered gothic arch ribs dress the streets. Ground routes pass below 4.5 m wide elevated pedestrian decks at 6 m height. Every district has an upper network connected to all four halls, whose interior ramps reach 6 m, 12 m and selected 18 m galleries. The street ceilings are around 11.7 m; taller hall alleys and gate vestibules provide changes of scale. Three small octagonal sky courts per district, including the capture court, interrupt the enclosure. Their nominal diameters are 16–20 m. Fixed gate openings remain 24 × 16 m and flare into vestibules before meeting the narrower roads.

The design uses the requested references as spatial inspiration: layered routes and gothic massing from Arcane Dimensions / Quake, arena overlooks from Unreal Tournament, and dense inhabited passages from Night City, Anachronox and Dark Forces II. Reference material consulted includes [Simon O'Callaghan's Arcane Dimensions pages](https://simonoc.co.uk/pages/design/sp/ad.html) and [Benoit Stordeur's Tears of the False God](https://bal.artstation.com/projects/B1yaX6). Geometry is original; the existing reviewed project materials, district colours, night sky, holographic gates and gothic science-fiction styling are retained.

**Jetpack design assumption:** two optional, nominal 4 m level gaps per district have broad 4 × 5 m landing pads. A 0.9 m wide, 1.8 m tall capsule is checked along a straight hop with 0.8 m arc rise. Low step-over deck curbs and generous overhead clearance accommodate limited steering. Both sides remain reachable using ordinary walking routes and ramps. This remains a geometric clearance envelope rather than a flight-time/control calibration; the [implemented CQ jetpack](CQ-JETPACK.md) now supplies a short arcing boost and stationary hover. Equipment and capture progression do not require flight.

All maps receive full VIS and RGB night lighting with 16-unit lightmap spacing, bounce and dirt. Street lamps and junction lighting are baked strongly enough to reveal sidewalks and parked vehicles; those bake emitters are not runtime point lights. Opaque walk-through holographic gates conceal the unloaded districts. The existing weapon/avatar illumination limit remains two effects, including on VR; translated BSP occlusion planes preserve wall blocking.

Maps use local coordinates, bounded by ±137 m horizontally including hidden gate continuations, and −3 to 112 m vertically. Runtime scenes are translated to the original city coordinates. The public play area ends at ±125 m. Gates align at 24 m wide and 16 m high; ordinary transfer is accepted only through the matching neighboring opening. The importer omits sky triangles, so matching client/worker collision caps close the space above the 36 m boundary walls and at the sky ceiling.

[Compare all sixteen enclosed layouts](validation/cq-enclosed-plans.png) · [Street-level render](validation/cq-enclosed-street.png) · [Upper routes](validation/cq-enclosed-upper.png)

## File budgets

The generator asserts format 29, disallows BSP2 promotion and checks engine/import budgets. Measurements for the committed pack:

| Resource | Smallest district | Largest district | All districts |
|---|---:|---:|---:|
| BSP bytes | 7,193,876 | 9,637,712 | 138,697,284 |
| Vertices | 11,747 | 14,372 | 210,311 |
| Faces | 8,767 | 10,815 | 157,181 |
| Nodes | 5,760 | 7,234 | 103,952 |
| Leaves | 3,430 | 4,309 | 62,205 |
| Marksurfaces | 12,408 | 15,398 | 222,412 |

Checks require vertices/faces/marksurfaces below 65,535, nodes/leaves/clipnodes below 32,767 and each BSP below FPSloppa's 25,000,000-byte import limit. Collision uses render triangles, so these builds use `-noclip`. BSPX RGB lighting supplements the version-29 geometry. This is a FPSloppa map pack, not a claim of unmodified Quake-engine gameplay compatibility. See the compiler's [format options](https://ericw-tools.readthedocs.io/en/latest/qbsp.html) and [limit-check history](https://ericw-tools.readthedocs.io/en/latest/changelog.html).

## Authority and handoff

The SHA-256 of `maps/CQDistricts/manifest.json` identifies the atlas. It binds every district's BSP, collision, presentation and navigation hashes. Workers validate their own server assets; clients validate all sixteen client assets at startup. The master checks the atlas identity and the assigned district BSP hash in each worker greeting. The public protocol is `fpsloppa-cq-experimental-4-jetpack-cq-district-bsp-1`, incompatible with ordinary CQ clients. Map downloads during connection are not implemented: install the matching pack beforehand.

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
python3 -m venv /tmp/cq-map-tools
/tmp/cq-map-tools/bin/pip install -r tools/cq_maps/requirements.txt
/tmp/cq-map-tools/bin/python tools/cq_maps/build.py --compiler /path/to/ericw-tools/bin
for district in $(seq 0 15); do
  godot --headless --xr-mode off --path . \
    --script tools/cq_maps/prepare.gd -- "$district" || exit
done
python3 tools/cq_maps/manifest.py
/tmp/cq-map-tools/bin/python tools/cq_maps/layouts.py
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

Preparation checks every spawn, pickup, hall level, ramp endpoint, authored street junction, access passage, elevated connection and gate route. It also casts collision rays across the carriageway and upward along the streets, requires at least 85% covered street samples in each district, checks that every courtyard has open sky, and sweeps capsule samples through both optional jetpack gaps. The current pack passes 2,009 navigation checks, 144 gate rays, 3,358 carriageway rays and 672 capsule-clearance samples. Covered street samples range from 90.2% to 96.3% across districts. All 48 sky courts retain open sky. The manifest requires the preparation receipt to match the exact compiled BSP hash. The layout review rejects street networks duplicated by rotation or reflection and generates `test-results/cq-maps/enclosed-plans.png`.

Geometry verification additionally checks translated floors/contents, portal rejection, sky containment, complete light atlases and translated illumination occlusion. Desktop street, interior, plaza, upper-route and sky-court views are rendered with `tools/cq_maps/views.gd`. Current measured results are recorded in [the enclosed-city receipt](validation/cq-enclosed-districts.json); [revision 2](validation/cq-urban-districts.json) and [revision 1](validation/cq-district-maps.json) receipts remain as historical evidence.

The current two-client ENet run passed bidirectional district handoffs, respawn, stale-generation rejection, restart and expected session shutdown on worker loss with 30 ms added private-link RTT. Gate pauses were 68–182 ms; prefetched scene activation took 19–22 ms, with no prediction resets and maximum measured correction error of 0.314 m. The bot smoke test uses a 90-second observation window because enclosed street travel and scavenging can exceed the old 25-second window. The completed run moved all 64 bots and recorded 808 transfers across sixteen workers, with occupancy at or below 16, one geometry instance per worker and zero on the master. Several bots repeatedly re-crossed gates (one reached generation 329); the handoff count is transport activity, not evidence of satisfactory strategic match flow. Gate goal persistence remains a bot-routing follow-up.

This is not a 64-human-client, headset, full-match balance or physical multi-host performance certification. Opaque gates conceal scene swaps but do not eliminate the authority-handshake pause. The master remains a serialization/bandwidth bottleneck and a single point of failure; district splitting does not increase the configured player or district counts. Existing ObjectDB/resource-in-use warnings remain during some test shutdowns; standalone desktop view fixtures can also report two small OpenGL texture leaks at shutdown.
