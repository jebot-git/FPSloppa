# Katabatic and ST weather

Katabatic is the third development ST map (`ctf_katabatic`), registered in the
map catalog and default ST rotation. It is a BSP29 adaptation of the **Tribes 2**
map, using its original mission positions, terrain samples and main-building
convex geometry. It is not the Tribes: Ascend remake.

The pinned input manifest is [references.json](../tools/katabatic/references.json).
Inputs come from the [t2-mapper archive](https://github.com/exogen/t2-mapper),
commit `abe5198e5020554fe1f1620231c188d48f00f045`; visual references include its
[Katabatic gallery](https://exogen.github.io/t2-maps/#Katabatic) and the
[Tribes 2 layout reference](https://wiki.tribesdepot.com/wiki/Tribes_2/Maps/Katabatic).
Original inputs remain in the ignored `tools/katabatic/local` folder.

## Runtime map

- 1,504 × 1,408 m terrain; flags 1,060.47 m apart; eight spawns per team.
- Original main-base ramps, rooms, flag shelves, small towers and vehicle decks.
  Remote four-pylon towers retain their positions and functional floor levels,
  with simplified geometry to meet BSP29 limits.
- Nine inventory stations per team, two main generators per team, independent
  power for each outpost, fixed turrets, remote pulse sensors and vehicle pads.
  T2 equipment uses the existing ST equivalents and vehicle sizes.
- Invisible perimeter, three surveyed terrain corridors, a ground navigation
  mesh and 335 supported indoor/landing navigation markers.
- Original 8 m terrain sampling near base cuts, 16 m approaches and 32 m distant
  terrain. Thin terrain shells near bases preserve the underground passages.
- Mipmapped Makkon and LibreQuake texture records, with provenance and hashes in
  [texture-sources.json](../tools/katabatic/texture-sources.json). Original T2
  texture art is not bundled. Geometry retains its source provenance.

The final BSP is 10,647,748 bytes, with 34,349 faces and 29,046 nodes. Full VIS,
coloured baked lighting and raw/BC7/ASTC4 scene caches are generated. The scene
caches use a packed 2048² lightmap. The map remains experimental; competitive
balance and headset performance have not been established.

## Weather

Snow is active on Katabatic and rain on Raindance. Each effect uses 512 analytic
particles in one MultiMesh draw, centred on the active viewport camera with
world-anchored fall phases. It has no physics bodies or network traffic. A cached
8 × 8 overhead survey hides precipitation below roofs/ground; moving one 4 m
cell needs only eight new rays. The survey runs at most 10 Hz, keeps 64 cells and
starts beneath the BSP sky seal. Roof edges have 4 m sampling precision.
Weather is absent on headless servers and fades close to the camera. The shader
uses separate eye view matrices for VR billboarding. Physical headset review of
the weather remains outstanding.

All three maps now use restrained, non-volumetric distance fog by default:

| Map | Clear until | Full configured blend at | Maximum blend |
| --- | ---: | ---: | ---: |
| Stonehenge | 240 m | 950 m | 22% |
| Raindance | 300 m | 1,200 m | 22% |
| Katabatic | 350 m | 1,400 m | 28% |

The curve is 1.5, with no height fog or sky tint. Map rotation restores ordinary
fog-free profiles elsewhere. Godot's [depth fog](https://docs.godotengine.org/en/stable/classes/class_environment.html#class-environment-property-fog-mode)
is supported by the Vulkan Mobile renderer used here; it avoids the Forward+
requirement and temporal cost of volumetric fog. This is a visual effect, not a
culling or network visibility rule.

## Reproduction and evidence

```sh
python tools/katabatic/prepare_sources.py
python tools/katabatic/build.py --compiler /path/to/ericw-tools/bin
godot --headless --xr-mode off --path . --script tools/katabatic/prepare.gd
godot --headless --xr-mode off --path . --script tools/katabatic/acceptance.gd
godot --xr-mode off --rendering-method mobile --rendering-driver vulkan --path . --script tools/katabatic/weather_preview.gd -- --no-bots
```

The source preparation needs Node 22+ for the pinned DIF parser. The generator
uses Python/NumPy and ericw-tools 0.18.1. Generated assets live under
`maps/Katabatic`, `maps/cache`, `maps/navigation` and `maps/ctf_katabatic.bsp`.
To resurvey portals after geometry edits, run `navigation_candidates.py`, then
`navigation_survey.gd`, rebuild and rerun acceptance.

Validation on 2026-09-29:

- 514 map acceptance checks pass: all spawns, station routes/service areas,
  three vehicle types per pad, independent power, flag fly-throughs and actual
  authoritative flag pickup/capture rules.
- 166 equipment alignment checks across all three ST maps pass; 59 ST mode
  checks pass. Existing sky and map-presentation checks also pass.
- 19 weather/fog checks pass using Vulkan Mobile, including roof masking,
  cache reuse, movement/teleport and map rotation. In-game captures were reviewed.
- A seed-9291, 6v6, 180-second match completed at 4× simulation speed: a capper
  took the blue flag at 158.18 s, dropped it at 163.15 s and blue recovered it at
  176.63 s. Score 0–0. This is a smoke test, not proof of capture reliability.

Evidence is in `test-results/st-katabatic`; the tracked receipt is
[st-katabatic-weather-2026-09-29.json](validation/st-katabatic-weather-2026-09-29.json).
Known test-fixture shutdown ObjectDB warnings remain; functional tests have no
script errors or failed assertions.
