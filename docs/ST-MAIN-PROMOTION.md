# ST promotion to main

29 September 2026: ST development is consolidated in the main checkout at
`/home/blux/Documents/FPSloppa`. The separate `st-raindance` worktree was removed.
ST is enabled, with Stonehenge, Raindance, Tribes equipment, armour, vehicles,
deployables, targeting, remote controls and the PDA. The published release was
not changed and nothing was pushed.

## Preservation and merge

Main's existing 183 source changes were checkpointed as
`07f727c58c9c0789b4aca7bb979e1b6f2899d4d3`. The previously validated ST/main
integration was checkpointed as `7a07cbf14285b474420149d0a3122bc66f342023`.
The `experimental/st-raindance` branch remains as a recovery reference; the
unrelated `experimental/cq-districts` worktree is untouched.

Seven merge conflicts retained the already tested integrated versions. All
4,642 tracked ST paths matched after resolution. The only later source changes
are the two test portability fixes described below. Main's native acceleration,
CS/DE improvements and map conversion work are retained. The native libraries
for Linux, Linux server, Windows and Android have matching source/build receipts.

Forty updated local runtime/source assets were copied, with previous main copies
backed up. All 154 audited local runtime/source assets still match after worktree
removal, including both ST maps and their caches. Import metadata and textures
extracted from the new GLB models are preserved in main. Blender generator roots
now resolve from their script location rather than the retired worktree.

The complete former worktree, including ignored artwork and test history, is in
`test-results/st-main-promotion/st-worktree-before.tar.zst` (7,987,530,236 bytes).
It was compared against the original directory with no differences before
removal. SHA-256:
`c570a375d62bd5d036ed209541fd35df0b8ac10039da8becf1119759e95f1d2d`.
The checkpoint also preserves the small generator/documentation changes made
after that archive. Main's prior source and overwritten runtime assets are saved
under the same promotion evidence directory. Recent integration evidence remains
directly available under `test-results/st-main-sync`.

## Checks from main

The final Godot import completed without errors. `Builds/.gdignore` prevents local
engine/compiler fixtures from entering future asset scans. The initial import
attempt and its diagnostics are retained in the evidence directory.

| Check | Passed assertions |
|---|---:|
| Native ST bot differential, 54 cases | 49,317 |
| Targeting laser and beacons | 43 |
| Commands, remote controls and Scout aiming | 46 |
| Transports | 93 |
| DE gameplay | 102 |
| CS recoil compensation | 470 |
| Vulkan armour replacement/culling | 226 |
| Vulkan VR command interface | 34 |
| Four-process targeting replication | 19 |

The DE test now checks that all five built-in maps are offered while allowing
installed converted maps. The VR command test creates its screenshot output
directory. These fix assumptions exposed by running in main; gameplay code was
unchanged. The armour gallery and command-panel captures were inspected.

An empty Raindance practice session was launched from main in actual WiVRn v26.9
on Quest Pro, using Vulkan. Its log reports `XR_READY OpenXR`, the Raindance map
ready and a practice host with no bots. The client subsequently exited with
status 0, with Godot/OpenXR cleanup diagnostics recorded in the receipt. This
establishes successful startup, not a new headset interaction or performance
assessment.

Existing test-fixture ObjectDB/resource cleanup warnings remain. Windows and
Android library validation is by their existing build receipts, not device tests.
Bot capture reliability remains unresolved as recorded in the
[integration report](ST-MAIN-INTEGRATION.md); no additional long match was needed
for this promotion.

Machine-readable results: [promotion receipt](validation/st-main-promotion-2026-09-29.json).
