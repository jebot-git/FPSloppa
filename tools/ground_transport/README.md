# LPMAC ground transport authoring

The original BlendSwap source is retained in `source/lpmac.blend`; it is not
modified by export. `source/provenance.json` contains the uploader/license metadata,
source checksum and zero-credit MCP procurement receipt, without credentials or
temporary signed URLs.

`export_transport.py` removes the weapon assembly and showcase, reduces geometry,
bakes the original colour networks and authors six side-pod entry/seat markers.
It writes the optimized runtime GLB, atlas and manifest under
`deathmatch/models/ground_transport`. `generate_geometry.py` derives the native
C++ dimensions/anchors from that same manifest. Rebuild the native extension after
regenerating it. A `--check` option detects stale native geometry.

Four transports spawn alongside the eight combat tanks: two team-0 carriers at
town/port road approaches, and two team-1 carriers at factory/military approaches.
Each carries six allies. The first aboard drives; control passes to the first
remaining occupant when the driver leaves or disconnects. Use beside a free pod
to board, and jump to dismount at a collision-tested exit. Use can also dismount.
All weapons and grenades are disabled aboard. Passenger cameras look directly
through the pod windows, with normal stereo rendering and no tank scope feed.

Mobility matches the rocket tank: 10 m/s forward, 5 m/s reverse, 0.65 rad/s turn,
4 m/s² acceleration and the existing 1.25× road multiplier. The transport is
unarmed, has 100 HP, uses the existing vehicle damage/repair/water rules and does
not hover. Occupants are released on destruction/reset/disconnection using
life-bound handles. The authoritative implementation is C++; the script service
retains equivalent controls for the existing fallback host.

Protocol: `fpsloppa-cq-frontier-20-transports`. The upper three bits of the existing
CQA2 class flags carry `seat + 1` (zero means unseated). Vehicle kind 3 is the
transport. No packet row size increases. Update client and server together.

Checks:

```sh
godot --headless --xr-mode off --path . --script res://tools/authority_core/transport_functional.gd
godot --xr-mode off --audio-driver Dummy --path . --script res://deathmatch/tests/cq_transport.gd
```

The standalone native test runner also includes `transport_tests.cpp`.
