# FortressOne TF map acceptance review

Reviewed 2026-09-11 against FPSloppa 0.8v (`f7f8073` plus the current movement/importer fixes).

**No maps accepted for the base TF bundle.** All four local conversions have incomplete bot objective routes, and none has a clear derivative-redistribution grant in its supplied documentation. Base assets and the default TF maplist were not changed.

| Map | BSP bytes | Traversal | Native TF objectives | Bot routes reaching both endpoints | Decision |
|---|---:|---|---|---:|---|
| bam4 | 1,985,116 | PASS | 8/8 passed | 0/128 | Local test only |
| 2mach1 | 626,476 | PASS | 8/8 passed | 0/32 | Local test only |
| 2castle1 | 1,435,024 | PASS | 8/8 passed | 2/24 | Local test only |
| openfire | 1,737,904 | FAIL: two beam-door collision probes | 8/8 passed | 0/80 | Local test only |

The eight native-objective checks per map cover both teams picking up and dropping the enemy flag, scoring at their native capture position, and healing at resupply. These are authoritative rule checks at actual map positions; they do not prove that players or bots can navigate between those positions.

All three bots moved more than two metres from their spawn area in every map during a 20-second production simulation. Bot navigation baked successfully, but the static walking routes did not connect every spawn to both flags and capture zones. Lifts, swimming and scripted barriers need map-specific navigation support; these maps are not ready for dependable offline TF matches.

Traversal coverage: 66 spawn movement probes, 25 swimming samples, 42 doors, 9 lifts, 4 teleporters, 4 push triggers.

Openfire’s failed door probes are the `bluebeams` (`*15`) and `redbeams` (`*4`) entities. Their opening/closing transforms complete, but the closed triangle probes do not find their collision. This is an unresolved probe/beam-semantics issue, not proof of a general engine collision regression. Original QuakeC team barriers and button/target chains are not implemented by the current generic BSP runtime.

## Visual review

Captured 24 graphical previews (spawn, flag and capture views for both teams) using the current Compatibility renderer. Inspected representative views from both teams across all four maps. LibreQuake surfaces and native team markers render; interiors and courtyards are too dark for confident combat readability, and the small replacement texture set is repetitive. Openfire’s beam geometry crosses the flag view. Retained these findings as acceptance blockers rather than declaring the conversions polished.

Local gallery: [previews](../test-results/fortressone-previews/index.html). Screenshots are local test output and are not included in the public repository.

## Provenance and conversion

Sources: [official FortressOne map repository](https://github.com/FortressOne/map-repo/tree/e9b4176be5a7be4a7eb072a529aa3df33d413bf6/fortress/package). Pinned URLs, Git blob identifiers and SHA-256 hashes are in [sources.json](../tools/fortressone/sources.json).

- Bam4: Brian Green / BaM]Midori[BH. No modified-distribution grant found in the supplied readme.
- 2mach1: >V<-Someone. Supplied readme has no derivative grant.
- 2castle1: Henry B. Tindall, Jr. / LanMan [Vortex]. Free sharing with credit is permitted, but modified distribution is not explicitly addressed.
- Openfire: no author readme present in the pinned package; rights unresolved.
- H4rdcore, Xpress, Aztec1 and Rock2 were not converted because their readmes explicitly prohibit unapproved modifications.

All four converted BSPs are below 25,000,000 bytes. Every embedded texture mip is replaced with LibreQuake pixels; missing entries receive a LibreQuake replacement. Texture lumps are rebuilt so unused original texture bytes are not carried over. Entity aliases are normalized, flags/capture zones become native FPSloppa markers, and team spawn rooms receive resupply. No original external sounds or models are copied. Every other BSP lump is byte-identical to its source, including geometry, visibility, collision and lightmaps. Conversions were reproduced and compared byte-for-byte.

Local assets and original notices: `../Builds/FortressOne-Local/`. Public tools and reproduction steps: [tools/fortressone/README.md](../tools/fortressone/README.md). The local `tf_fo_maplist.txt` is an explicit test list, not a default rotation.

## Evidence and limits

- `test-results/fortressone-traversal/`: input entities, movement/brush results and engine logs.
- `test-results/fortressone-playtest/`: per-team objective checks, route results, bot displacement and graphical test logs.
- `test-results/fortressone-conversion.json`: reproducibility and unchanged geometry/collision/lightmap verification.
- `test-results/fortressone-previews/`: 24 PNGs and local gallery.

No engine errors were reported in completed map tests. Two ObjectDB instances were reported as leaked during graphical playtest teardown; that warning was not counted as a gameplay pass. These short desktop automated playtests do not establish Quest/Pico frame rate, human match balance, complete map exploration or network behavior on these maps.
