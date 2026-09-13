# Assault default and Tiny layouts

The expanded layouts were promoted to the defaults on 2026-09-12. The original
compact layouts remain as Tiny variants intended only for 2-4 players (1v1/2v2).
The normal AS rotation includes the two expanded maps; Tiny maps are selectable
in Host and may be explicitly included in a server's `as_maplist`.

| Map shown in Host | Map ID | Horizontal change from Tiny |
| --- | --- | --- |
| HiSlop | `as_hislop` | 1.75× length, 1.25× width |
| Frigate | `as_frigate` | 1.60× length, 1.30× width |
| HiSlop Tiny (2-4 players) | `as_hislop_tiny` | Original compact layout |
| Frigate Tiny (2-4 players) | `as_frigate_tiny` | Original compact layout |

`server.cfg` in this folder now selects the expanded defaults. The old
`*_layout_test` IDs are retired; update custom playtest configs to the standard
IDs above. All four maps and their caches/navigation are included by the base
asset pack builder.

HiSlop keeps the seven-car sequence and roof approach. The six inter-car gaps now
have overlapping, full-width deck plates spanning both side walkways, with outer
guards. Freight cars and the slime catwalk have low side guards. The four CAR 3
defender rooms have separate doorways into a central passage. CAR 2 has alternating
upper passenger-room doors. CAR 1's switch is farther forward, above the control
cabin, behind a second upper compartment; attackers return via the stairs and
lower service passage. The final attacker checkpoint respawns at CAR 1's entrance.

Frigate expands the warehouse/quay approach and ship compartments, retains both
gangway and underwater entry, and separates the aft crew room from the mess.
The lower starboard passage has independent door openings beside the stairwell,
providing a second route to the compressor instead of another dead end. Compressor
health, objective order, unlock rules and round timers are unchanged.

Vertical dimensions are deliberately unchanged: stair rise is still 16 Quake
units (0.5 m), door clearance remains 112 units (3.5 m), and water/sludge depths
are preserved. Texture density is unchanged; textures are not stretched with the
geometry. Pickups retain the runtime's fixed centring offset. Full VIS, lighting,
scene caches and navigation are rebuilt for the new geometry.

## Reference and limits

The [HiSpeed reference](https://unrealarchive.org/wikis/the-liandri-archives/AS-HiSpeed.html)
documents the seven wagons, CAR 3 defender rooms, obstructed CAR 2 lower route,
and upper-switch/lower-cabin sequence. The
[Frigate reference](https://unrealarchive.org/wikis/the-liandri-archives/AS-Frigate.html)
documents warehouse/bar, gangway and underwater approaches, lower rooms, aft
compressor, mess and upper controls. Existing reference research and screenshots
are documented in `tools/hispeed_concept/README.md` and
`tools/frigate_concept/README.md`.

Room sequence and connections inform this revision. **These dimensions are
estimates for FPSloppa, not measurements of retail Unreal maps.** The new routes
still benefit from paired, equal-team human balance testing. In particular, check
whether the longer open approaches favour snipers too much, whether guards make
the train's exterior route too safe, and whether defenders can reasonably cover
both ship entrances. No multiplayer balance claim follows from solo traversal.

New geometry code is CC0-1.0. The included texture provenance and LibreQuake
notices apply to the embedded art. No Unreal packages or extracted art are used.

## Rebuild and validate

```sh
python3 tools/assault_layout_tests/build.py --compiler-dir /path/to/ericw-tools/bin --install
godot --headless --xr-mode off --path . --script res://deathmatch/tests/hislop_interior.gd -- res://maps/as_hislop.bsp
godot --headless --xr-mode off --path . --script res://deathmatch/tests/frigate.gd --
python3 tools/frigate_concept/test_network.py
```

The installer builds both expanded and Tiny variants, updates their catalog entries,
and keeps Tiny outside the default rotation. Use `--tiny` with the traversal tests
to check compact maps.
Generated MAP/WAD sources, compiler logs, screenshots, timings and gameplay results
are under `test-results/assault-layouts/`. Add `--views` to either Godot test and
omit `--headless` to refresh screenshots. The saved validation report is
`docs/validation/assault-layout-tests.json`.

## Earlier layout validation, 2026-09-12 (before promotion)

81 checks passed on the variants: 33 train collision/navigation/objective checks,
29 ship gameplay checks, four sludge-escape refresh rates and 15 ENet replication
checks. Another 36 checks passed on the unchanged original maps. Screenshots of
the new rooms, car crossings, harbor and corrected service passage were inspected.

| Solo walking route at 5.2 m/s, without combat | Original | Layout test |
| --- | ---: | ---: |
| HiSlop upper switch → lower controls | 8.1 s | 14.2 s |
| Frigate attacker spawn → compressor approach | 20.8 s | 31.4 s |
| Frigate compressor → upper controls | 12.9 s | 20.2 s |

These are measured collision-traversal timings, not predicted match completion
times. Full-VIS BSP sizes are about 3.28 MB and 2.50 MB. Navigation has 2,734 and
965 polygons respectively; larger routes still need multiplayer/hardware profiling.
The existing one-instance ObjectDB warning at test exit also occurs on the
original maps. There were no new engine errors. No live VR or human balance test
was performed in this pass.

For balance testing, keep teams and movement settings identical between the old
and new maps, swap attack/defend roles, and record both legs. Compare time to first
contact, time to each objective, defenders alive/in position at first contact,
environment deaths per crossing, and completion rate. Test 2v2 and 4v4 before
raising player count. Include roof attacks, side-walkway strafing and knockback,
sludge recovery, both Frigate entrances, checkpoint respawns, and VR hand Use.
