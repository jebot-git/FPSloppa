Current CQ tier assets (2026-10-16) use the requested source weapon family. The older modular/orange family described below is historical. `tier_sources.json` pins new downloads and their authors/licenses; `sources.json` retains the hand cannon, Massacre, carbine and sight provenance. The BlendSwap energy minigun was acquired through authenticated BlendSwap MCP with a free download. Credentials and signed URLs are never stored in the repository.

Rebuild current assets with `fetch.py`, `fetch_tiers.py`, then Blender `--background --factory-startup --python tools/cq_assets/build_tiers.py`. Run `python tools/authority_core/generate_weapon_geometry.py` and `python tools/cq_assets/validate.py` afterwards. Editable current assets are in `tier_authoring/*.blend`; runtime files use a single gunmetal 1024px atlas/material, with separate magazines and reload parts. Source luminance and baked occlusion retain surface detail while removing bright/pastel finishes. Carbine geometry is retained from the original optimized authoring file.

Standard weapons remain within 5,000 **triangles**, including attachments. Complex burst/scout/beam/launcher/minigun models may use up to 7,000 triangles (a conservative interpretation of the requested 7,000 polygon limit). Complex assets bypass planar dissolve. Local aperture clipping avoids whole-object Boolean damage to disconnected source meshes. Magazine placements are model specific: bullpup assault/railgun, stock-fed SMG1, diagonal SMG2 guard, forward SMG3/T2 pistol, grip-fed base/scout pistols, forward burst/Akira, side Massacre and bottom minigun box. The beam rifle retains its authored animated power cell plus moving receiver/grip paths from the FBX. Native extraction axes and sockets are generated from the same manifest used for rendering.

Only the carbine, assault rifle and modeled burst optic use red-dot rendering. Other pistols, SMGs, technician weapons, railgun and repair tool have no added dot. The burst optic is fixed at 1.5x; the railgun's local display tracks enemy positions within 150m. Weapon statistics and the new unlock thresholds are initial tuning and require live balancing.

Legacy CQ assets and source tools use the OpenGameArt assets and author credits listed in [sources.json](sources.json), with pinned SHA-256 hashes. The original weapon silhouettes, pistol magazines/wells and carbine clip are retained. The scout model includes the source scope, stock and silencer. The designator's forward direction is corrected. The launcher has a side-loading three-charge pack; other tools include the cordless drill, sci-fi grenade and the two linked supply cases.

The legacy export has fewer than 1,000 triangles, one material and one 512×512 diffuse atlas. The launcher also uses a 12-triangle pack sharing its atlas at runtime. The editable finish master was painted through Krita MCP and is retained as `finish_master.kra` alongside its PNG. Blender 4.5.9 LTS evaluates source modifiers, reduces geometry, unwraps UVs and bakes the finish onto the reduced meshes. The generated injector uses the same finish.

OpenGameArt lists all selected sources as CC0. The two Yughues/Nobiax case archives contain older CC BY-SA 3.0 notices; these notices are preserved in `deathmatch/weapons/cq`. To honor those notices, distribute the derived ammo/medical case assets with attribution to Yughues/Nobiax under [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). Original finish artwork and injector geometry are CC0. Source game sounds are separate from these model licenses.

Rebuild from the repository root:

```sh
python3 tools/cq_assets/fetch.py
blender -b --factory-startup --python tools/cq_assets/build.py -- test-results/weapon-sources deathmatch/weapons/cq
```

Krita GUI `/usr/bin/krita` with the Krita MCP addon was used for painting. Blender MCP was unavailable in the initial legacy session, so Blender's batch Python API performed the bakes. Runtime gallery/effect checks use Vulkan Forward+ in `preview.gd` and `preview_fx.gd`.

Class icons are original CC0 vector glyphs in the bundled 1.6 KB font, with ordinary text using Godot’s fallback font. Regenerate with `uv run --with fonttools python tools/cq_assets/build_class_icons.py`; render with `--script tools/cq_assets/preview_names.gd`. Private-use codepoints avoid platform emoji substitution.

The current firearm family replaces the failed T2 decimation experiment and rebuilds the starter weapons as well. All ten firearms derive from Felix Kütt’s CC0 [sci-fi rifle](https://opengameart.org/content/sci-fi-rifle), using its receiver, grip, bridge, housing, muzzle and magazine modules. JeanPFP’s CC0 [red-dot sight](https://opengameart.org/content/red-dot-sight) is retained and refinished where a full scope or iron sight is absent. The supplied orange/black reference guided stocks, barrel configurations, ceramic windows and proportions. The discarded SMG/energy-rifle/assault-rifle/Akira/EMG sources are no longer used.

`modular_finish.kra` is the editable orange/graphite/ceramic/steel palette painted through Krita MCP. `modular_authoring/*.blend` retains the named editable modules and the corresponding baked export. Blender 4.5.9 LTS and Blender MCP were used to author and inspect the new family. The exported weapons have one 1,024×1,024 atlas and one material each; charging handles and magazines/packs retain that atlas on separate movable nodes. Source render visibility is disabled during the target AO bake. Source UV maps are replaced with one square atlas UV map.

The initial detailed prototype deliberately deferred geometry optimization at the user's request: those are shape/finish prototypes, with manufactured bevels and weighted normals, and **are not under the earlier 1,000-triangle limit**. The initial manifest marked them `optimization_pending`; the optimised runtime exports clear this flag. Tools/cases retain their previous limits. Rebuild the family after fetching the pinned carbine and sight sources:

```sh
blender -b --python tools/cq_assets/build_modular.py -- test-results/weapon-sources deathmatch/weapons/cq
python3 tools/cq_assets/validate.py
```

The original `build.py` rebuilds the legacy set; run `build_modular.py` afterwards to restore the current family. New finish artwork and authored modules are CC0, matching the carbine and sight sources.

The subsequent optimisation pass now supplies current runtime exports below 1,000 triangles, including reload parts. It preserves the original detailed `modular_authoring` set; editable optimised modules are in `optimized_authoring`. Material-preserving planar dissolve, selective receiver bevels and eight-sided open bores reduce geometry without collapse decimation. The target geometry is unwrapped and rebaked to the same 1K palette/AO atlas. Use `build_modular.py ... --optimized` to rebuild current runtime assets, or append `--audit` for geometry counts without baking. See [validation and rendering comparison](../../docs/validation/cq-weapon-optimization/README.md).

Current fitted pistol bases cover the lower magwell, the scoped stock enters its receiver, and launcher packs/screens use fixed sockets/pedestals. Launchers have no charging handles. Detailed and optimised authoring modules are updated; the existing palette and source licences are unchanged. See [fittings and runtime statistics](../../docs/validation/cq-weapon-fittings/README.md).
