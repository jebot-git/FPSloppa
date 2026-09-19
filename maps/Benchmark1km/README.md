# Vesper Megalopolis

A decorated science-fiction city with gothic architecture, built on the existing **1,000 × 1,000 m BSP29 prototype**. Sixteen 250 m districts retain their original boundaries, 64 spawns, 128 pickups, connected streets, and low accessible galleries. The map remains an experimental environment rather than a production competitive map.

The districts share iron, stone, monumental lancets, illuminated transit axes, and reliquary street furniture. Their materials, accent colours, rooflines, and landmarks differ: Cathedral Exchange, Helix Arcology, Crucible Works, Astral Observatory, Reliquary Archives, Synapse Data Vault, Pilgrim Transit, Sanctum Medica, Blackwater Condensers, Ember Market, Cipher Court, Aegis Bastion, Verdant Cloister, Meridian Reactor, Iron Docks, and Crown Necropolis.

## Geometry and presentation

The BSP contains the textured buildings, layered cornices, buttresses, spires, industrial stacks, streetlights, shrines, consoles, cargo, pavements, galleries and ramps. A solid 30 m perimeter encloses the city; the outer sky shell reaches 160 m. Forty-nine textures span the reviewed industrial, masonry, copper, wood, machinery, container, rune and gothic relief libraries. `texture-sources.json` records each embedded texture's original pack and provenance; their existing licences still apply. The new geometry and procedural effect code are original project assets. `city.wad` is reproducible from the project's texture dictionary.

The nighttime lighting uses full VIS, supersampled RGB lightmaps, one diffuse bounce and ambient dirt. Moon/sky/minimum contributions are 9/4/1; 1,424 baked emitters match windows, lanterns, gates, braziers, roof bands and rings. The night response preserves dark shadows instead of lifting them to grey. The city uses 32-texel lightmap spacing, independent of the full-resolution surface textures. The night panorama comes from the existing CC0 Screaming Brain Studios sky library. `-noclip` omits legacy Quake movement hulls: Godot builds real collision from the imported surface mesh. Decorative brushes use `func_detail_wall` to avoid unnecessary splits in large building surfaces. The finite BSP29 geometry budget is checked by the compiler; this map is close to its vertex limit.

The prepared scenes add district-batched emissive windows, lanterns, roof beacons, orbital rings, technological foliage, brazier fixtures and restrained steam. These add no real-time lights or per-frame GDScript processing. Steam is capped at two small shader-driven wisps per district. Native box occluders cover only known solid architecture and the opaque gate curtains.

All 24 district passages have an **opaque, walk-through holographic gate**, with separate faces belonging to their two streamed districts. The depth-writing shader deliberately has no alpha output. Destination names and sector numbers face approaching players. The gates have no physics bodies, so they cannot block movement or projectiles. Divider headers frame the 24 m wide, 16 m high openings.

The original BSP importer representation is stored in `baseline-lightmap1.scn`. `zones-lightmap1.scn` includes decoration and ordinary spatial occlusion; preparation also saves its texture-versioned alias required by the normal loader. `districts.scn` clips the static geometry at district boundaries and groups the same decoration by district for the independent simulation prototype. Loading only the raw BSP supplies its geometry and baked lighting; the Godot presentation layers require these prepared caches and harnesses.

## Rebuild and inspect

```sh
python3 tools/km_benchmark/build.py --compiler /path/to/ericw-tools/bin
godot --headless --xr-mode off --path . --log-file /tmp/city-prepare.log --script res://tools/km_benchmark/prepare.gd
godot --headless --xr-mode off --path . --log-file /tmp/city-districts.log --script res://tools/district_sim/prepare.gd
godot --xr-mode off --audio-driver Dummy --path . --resolution 1600x900 --log-file /tmp/city-views.log --script res://tools/km_benchmark/city_views.gd
godot --xr-mode off --audio-driver Dummy --path . --resolution 1280x720 --log-file /tmp/city-live.log --script res://tools/district_sim/run.gd -- '{"zones":16,"seconds":32,"speed":4,"name":"city4x","port":29349}'
```

Preparation verifies baked face coverage, decorated cache resolution through the normal loader, navigation connectivity from all 64 spawns, floor collision, 16 perimeter collision rays and 144 gate-clearance rays. Navigation uses 1 m horizontal / 0.25 m vertical cells, a conservative 1 m agent radius and 1.75 m height. The district harness exercises 64 bots, snapshot subscriptions, ownership transfers and normal gate crossings. Results are under `test-results/city/`, `test-results/km-benchmark/` and `test-results/district-sim/`.

`graybox.py` retains the former sparse benchmark generator. Its historical measurements in [KILOMETRE-BENCHMARK.md](../../docs/KILOMETRE-BENCHMARK.md) describe that old scenery and should not be presented as measurements of this decorated city. Production maplists and base asset packaging are unchanged. The full nighttime bake is documented in [CITY-NIGHT-LIGHTING.md](../../docs/CITY-NIGHT-LIGHTING.md). The server/client feasibility assessment is in [DISTRICT-SERVER-INTEGRATION.md](../../docs/DISTRICT-SERVER-INTEGRATION.md). Final measurements and screenshots are in [CITY-DECORATION.md](../../docs/CITY-DECORATION.md).
