# Skybox selection and validation — 13 September 2026

Five freely redistributable cloud panoramas now replace the procedural gradient on 17 sky-visible base maps. The other eight base maps retain their existing background. Original BSP geometry, embedded sky textures and map lighting are unchanged.

## Sources and distribution

Selected: **Cloudy Skyboxes by Screaming Brain Studios, CC0 1.0**. The [author’s asset page](https://opengameart.org/content/cloudy-skyboxes-0) permits redistribution in commercial and non-commercial projects. The original licence is included beside the PNGs, and [SOURCES.json](../deathmatch/maps/skies/SOURCES.json) records archive/file hashes. Only original panoramas 10, 12, 18, 20 and 22 are bundled, renamed to descriptive filenames; their pixels are unchanged. Together the five 2048×1024 PNGs total **5,123,006 bytes (4.89 MiB)**.

Also inspected: [Kenney Skyboxes](https://opengameart.org/content/skyboxes-1), also CC0; the bright stylized candidates fit these maps less well, and the space panorama was unnecessary because Skyfracture has no sampled sky opening. [Poly Haven pure skies](https://polyhaven.com/a/kloppenheim_06_puresky) are another CC0 source, but higher-resolution HDR lighting assets are unnecessary for this background-only use. Unselected packs remain under ignored test-results, outside releases.

## Map matching

The audit traces each current BSP world tree from spawn/item eye positions and sampled floor centers. At each point, 96 rays cover four elevations and 24 azimuths. A ray must enter a sky-content leaf before a solid leaf. Every selected map had a positive spawn/item sightline, not just an isolated roof sample. Screenshots verify the corresponding opening in the actual renderer. Static traces do not model moving doors; a zero result is a bounded audit finding, not proof that every possible viewpoint is enclosed.

No base worldspawn names an external skybox, and no base-map panorama/cubemap set was found. Several BSPs contain 256×128 two-layer Quake sky textures; the existing loader omits their sky surfaces. Those source textures remain untouched. This change replaces the currently rendered procedural background, rather than modifying embedded Quake artwork. Explicit panorama/custom sky materials already installed in an environment are preserved.

| Panorama | Matched maps | Reason |
|---|---|---|
| Storm | `as_hislop`, `tf_pressureworks`, `qsrc_dm3` | Slate storm clouds fit rail yards, power works and military architecture. |
| Overcast | `as_frigate` | Muted green-grey cloud cover fits the Frigate dock and ship. |
| Night | `tf_vesper`, `cc_ghostquarter`, `qsrc_dm4`, `qsrc_dm5`, `qsrc_dm6`, `ctf_crownreach` | Violet night complements Gothic stone, ruins and classic Quake skylights. |
| Winter | `koth_solstice`, `koth_hyperborea`, `cc_hyperborea`, `qsrc_dm7` | Cold haze fits Arctic/coastal stone and open courtyards; restrained contrast keeps silhouettes clear. |
| Ember | `koth_torture`, `cc_psychofuge`, `qsrc_dm2` | Burnt-orange cloud fits lava, rust and infernal arenas. |

No new panorama: `koth_alichar`, `cc_basement`, `qsrc_dm1`, `ctf_tideworks`, `ctf_crucible`, `ctf_confluence`, `ctf_deepvault`, `ctf_skyfracture`.

Exact SHA256 aliases preserve these assignments when a known base BSP is downloaded from a server under a `custom_<hash>` identifier. Unrecognized imported maps keep the existing fallback. A revised BSP hash needs a new audit/alias before this automatic download recognition applies.

## Engine and VR behaviour

Integration uses Godot’s native [PanoramaSkyMaterial](https://docs.godotengine.org/en/stable/classes/class_panoramaskymaterial.html), with static quality-mode Sky resources and a 128-pixel radiance cache. Environments and textures are reused across maps with matching settings. Full-resolution mipmaps and high-quality BC7/ASTC 4×4 imports are enabled; each compressed panorama uses about 2.67 MiB including mipmaps. Brightness is scaled at runtime to suit each map. Existing ambient light and reflection policy are retained. Skyboxes are now default behaviour; the graphics toggle and all map fog were removed. There are no sky meshes, colliders, additional cameras or moving clouds in gameplay.

The engine renders the background at infinity, which suits VR. A native Mobile/Vulkan test compares 64 mm-separated eye positions, several metres of room-scale translation and head rotation. All five skies produced identical left/right and translated backgrounds, and changed correctly with rotation. This is a stereo camera test, **not** a live OpenXR headset or standalone Quest test.

## Validation

- All 17 selected maps loaded and produced before/after screenshots at audited sightlines on Godot 4.7.2 Mobile/Vulkan (Intel Arc A770, 960×600, 4× MSAA).
- Sky selection, server-download aliases, explicit authored-sky preservation, unknown-map fallback, enclosed maps, environment reuse and lighting preservation pass the skybox fixture. Existing map-presentation tests also pass.
- All five panoramas pass the stereo/translation/rotation checks. Desktop BC7 and Android ASTC 4×4 import artifacts now exist with mipmaps; see the later [static-assets validation](STATIC-ASSETS.md).
- The console-only server package audit passes and contains no skybox textures, sky catalog or atmosphere scripts. No gameplay networking or collision changes were needed.

GPU median changes across the 17 paired previews ranged from -0.044 to +0.012 ms (median -0.006 ms), with unchanged draw-call counts. These small differences are within timing noise; this is not a headset performance benchmark. See [structured results](validation/skyboxes.json).

The full-map preview reports six ObjectDB instances and one resource still in use at shutdown. The isolated panorama/stereo fixture retains only the common one-instance shutdown warning. This does not establish a gameplay leak, but the full preview cleanup warning remains recorded rather than being counted as a clean shutdown.

Raw evidence is under `test-results/skyboxes/`: `map-audit.json`, `unit.log`, `map-presentation.log`, `stereo.json`, `render/results.json`, individual before/after images and `map-previews.jpg`. The full editor import also reported pre-existing BSP convex-hull/import cleanup errors in unrelated assets; the selected textures imported and the dedicated runtime fixtures loaded them successfully. Headless probes retain their existing single ObjectDB shutdown warning.

Reproduce with `python3 tools/skyboxes/audit.py`, then the `deathmatch/tests/skyboxes.gd` fixture, `python3 tools/skyboxes/run_render.py` and `python3 tools/skyboxes/run_render.py --stereo`. Renderer runners are bounded and reap their own process. No release was published.
