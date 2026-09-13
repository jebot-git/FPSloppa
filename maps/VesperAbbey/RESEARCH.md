Vesper Abbey research and validation — 12 September 2026

An original gothic TF map for FPSloppa, targeting 6v6 and supporting 4v4–8v8. The previous Pressureworks work established the process: examine reference maps and gameplay evidence, preserve original texture records with provenance, compile sealed original brushwork, render it, bake symmetric navigation and exercise real movement/objectives before packaging.

**References and use**

- [well6 original archive](https://www.quaddicted.com/files/maps/multiplayer/well6.zip): inspected the original BSP's four tower lift entities and their matching `trigger_multiple` targets. The reference uses upward `func_door` brushes at 170 Quake units/second, a four-second top dwell and 11-second trigger cooldowns. FPSloppa's existing well6 regression records show approximately 17.22 m of lift travel, successful round trips with riders and late-join synchronization. `well6-evidence.json` pins the archive/BSP hashes and records the relevant entity values. No reference geometry, textures or full BSP is included in this package.
- [Makkon Textures, version 990](https://www.slipseer.com/resources/makkon-textures.28/): downloaded the dedicated Gothic Stone archive and inspected its example screenshots, readme and trim guidance. The examples informed the architectural material roles: pointed arches, slender shafts, tracery, rose panels and spires. No example-map brushwork was copied. The original texture files are verified byte-for-byte and their licence matches the existing FPSloppa Makkon notice.
- [ericw-tools QBSP documentation](https://ericw-tools.readthedocs.io/en/latest/qbsp.html): the locally installed v0.18 documentation describes `func_detail` brushes merging into world geometry without becoming structural visibility splitters. This keeps the decorative spires and trim inexpensive to compile while retaining collision.
- The Quake TF videos, transcript, demo and map studies documented in [Pressureworks' research](../Pressureworks/RESEARCH.md) supplied the existing principles: separated spawn/flag/capture locations, understandable routes for every class, and alternate approaches to defended objectives. They are background research, not evidence that this new map is competitively balanced.

**Distinct layout**

Pressureworks centres on a raised turbine yard with deep ground-level flag vaults. Vesper instead has an interrupted cruciform nave, offset cloisters and elevated flag sanctuaries. Two lifts in each base arrive from different directions, while a permanent 24 m ramp climbs eight metres from the outer cloister. Flags sit upstairs; capture altars and resupply remain downstairs. Eight screened spawns per team sit away from both objectives.

The playable footprint is 128 × 80 m. Geometry, objective placement, pickup placement and navigation topology are equivalent under a 180-degree rotation. Red and blue rose windows distinguish the bases. A nave wall prevents direct ground-level base-to-base sniper fire; caskets and cloister walls break the perimeter approach into encounters. Lifts trade speed for exposed boarding and landing positions. The permanent ramp means a defender cannot deny the only route by controlling a lift.

The four elevators are six metres square, rise eight metres in two seconds, dwell three seconds upstairs and return automatically. A small raised deck gives the moving collider an unambiguous boarding surface. Upper landing approach triggers can call them from downstairs. This is the same trigger-operated vertical-door family used by well6, with dimensions and timing authored for this layout.

Sixteen original textures are embedded: ten from Makkon Gothic Stone, two from Makkon Metal and four LibreQuake textures. Rose-panel UVs fit each architectural face; pixels, palette indices and mip levels are unchanged. The compiler's missing `trigger`/`skip` utility-texture warnings concern invisible logic/removed faces, not missing artwork on playable surfaces. The original art audit checks every used visible texture.

**Acceptance of this build**

All 97 checks passed. All 64 spawn-to-objective navigation paths connect; all eight physical Heavy walks reach their destinations without jumping. The two navigation flag-return routes are 120.79 m each. Physical Heavy returns covered approximately 120.89 m in 19.62 seconds, excluding combat.

All four lifts activate on boarding, carry riders through their full travel, return with riders, allow walking onto fixed upper landings, and respond to the upper call zones. Late-join position resumption and completion of remaining travel pass. Actual sentry damage, the existing 18 m range cutoff and wall occlusion also pass. No game-wide sentry tuning was needed.

| Match | Duration | Red–Blue captures | Red/Blue flag pickups (flag colour) | Frags |
| --- | --- | --- | --- | --- |
| 4v4 | 30 s | 0–0 | 1 / 2 | 4 |
| 6v6 | 90 s | 1–1 | 5 / 1 | 23 |
| 6v6 with teams swapped | 90 s | 0–2 | 7 / 1 | 24 |
| 8v8 | 30 s | 0–0 | 1 / 1 | 4 |

These short matches demonstrate activity and objective access. They do not establish human competitive balance or equal class effectiveness. Run two human 10-minute halves with teams swapped, then compare 4v4 and 8v8, paying particular attention to lift camping, ramp pressure and spawn-to-defense recovery time. Bots have verified permanent walking routes; the acceptance report does not claim that they tactically exploit all four elevators.

`validation.json` ties these results to the exact BSP, navigation and runtime-code fingerprints. Godot emits its pre-existing ObjectDB cleanup warning; no script/engine errors were accepted in the test phases.

[View the in-engine elevator demonstration](lift-demo.mp4). The clip illustrates production elevator motion; rider and trigger correctness are tested separately by `tools/vesper/lifts.gd`.
