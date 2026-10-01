FPSloppa weapon authoring pipeline

The runtime exports are deathmatch/weapons/fidelity/*.scn, *_albedo.res and *_orm.res.
Their source declarations, model hashes and required notices are in that directory.

Source caches are deliberately ignored. Public source URLs and downloaded-file
hashes are recorded in downloads.json, blendswap-downloads.json,
reference-downloads.json, additional-donors.json and polyhaven-downloads.json. Source .blend files are
loaded as library data in disposable Blender sessions with auto-execution off.
No source script from downloaded assets is run.

1. Preserve the original bases/*.glb and bases/anchors.json. Do not regenerate
   baselines from a build that already has fidelity assets integrated.
2. workshop.py prepares the original CC0 catalogs. prepare_additional.py prepares
   the selected OGA and pinned LibreQuake models from their source caches.
3. Krita source: weapon-panels.kra, with separate material and detail layers.
   The exported weapon-panels.png and generated material-swatches.png are used
   by finishes.py. krita_surface_workshop.py reproduces the layered artwork;
   run it only with our weapon-panels.kra document active in Krita MCP.
   realistic-surfaces.kra / .png add recolored CC0 photographic grain for CS/ST.
   krita_realistic_surfaces.py creates that layered document through Krita MCP.
4. Blender build.py [-- rules_slot ...] fits donor_edits.py/designs.py/
   tribes_designs.py to anchors from dimensions.py, bevels and UV-bakes 512px textures.
   dimensions.py combines preserved baselines with fidelity/dimensions.gd.
   ut99_designs.py, tribes_refine.py, cs_refine.py and working_parts.py author
   the revised assemblies, grip furniture and moving components.
   Outputs: refined/<rules>_<slot>.blend, .glb, _albedo.png, _orm.png and .json.
5. Godot --headless --xr-mode off --path . --script
   tools/weapon_sources/fidelity/import.gd [-- rules_slot ...]
   generates compressed runtime scenes/textures and restores Godot metadata.
6. Run validate_fit.py in Blender for mesh-to-palm checks. Native Godot tests:
   cs16_sights, cs16_art, tf_weapon_art, weapon_setup, weapon_variants,
   tribes_arsenal, weapon_presentation, cs16_vr_reload, cs16_reload_ui
   (under deathmatch/tests/).
7. tools/weapon_presentation_preview.gd renders fixed-scale loadout sheets.
   profile.gd measures factory CPU costs, not VR frame time. review_scene.py
   refreshes a dedicated live Blender scene while preserving other scenes.

Current validation: test-results/weapon-fidelity/validation.json.
Current visual sheets: test-results/weapon-fidelity/furniture/.
Individual updated model views: furniture/closeups/.
Animated native preview: revision/mechanisms.mp4.

Design decisions:
- Retro Style Pistol is the Doom pistol donor; Fallout Shelter Laser Pistol is
  remodeled into the ballistic Enforcer (short guard and bored muzzle).
- Sci-Fi Rifle supplies related plasma/BFG receivers. Its discussion image was
  studied for the shared-receiver approach, not copied as texture artwork.
- Energy Rifle and AKIRA rifle supply edited shock/redeemer bodies.
- JohnnyBlack's chainsaw supplies the textured motor, handles and chain bar.
- Blaster Kit was inspected and retained as an optional future part library;
  its toy-like whole-weapon silhouettes were not used in this pass.
- Five LibreQuake weapon bodies are used under BSD-3-Clause with bundled notices.
  OpenArena permits GPLv2 reuse with corresponding editable source obligations;
  no OpenArena model was imported.
- CS sight geometry, palm anchors, damage and timing remain protected.
  Five longer heavy weapons use shared updated shot origins at their barrel tips.
- Pulse uses one exposed energy accelerator; rocket uses six launch tubes.
  Bio upper-body width/height grew modestly without changing its grip or muzzle.
- Material-response textures preserve distinct wood/polymer/metal roughness.
  Emitters brighten per instance; vents, coils and breeches settle and sleep.

2026-10-01 targeted furniture and assembly pass:
- tribes_detail.py fits the CC0 Firearms Kit stock.009 to ST plasma, chaingun,
  grenade, laser and mortar; disc receives only a rear cast cover and finish.
- Laser has a shaped walnut fore-end with a palm swell and relieved nose.
- cs_furniture.py replaces Glock/USP/Deagle grip furniture with contoured
  Firearms Kit grip.001, cuts the actual magazine volume, and sweeps rounded
  guards. P90 lower shell is narrowed and its silhouette edges rounded.
- furniture-surfaces.kra/.png retain photographic grain, polymer stipple and
  separate handling wear. krita_furniture.py reproduces this Krita document.
- UV islands are explicitly packed together before baking; two-pixel dilation
  avoids adjacent islands overwriting small sight and hardware colors.
- Grenade range sight has a receiver-mounted dovetail. Mortar has a closed
  dished breech and saddle. Plasma has a power-cell saddle, hood seats and
  transverse retainers that still intersect the vent leaves at full lift.
- validate_assemblies.py checks mesh intersections and a closed breech shell.
- Approved Doom/Quake/UT and ST blaster/ELF/repair/targeter runtime assets were
  not rebuilt by this pass.

2026-10-01 final topology pass:
- Laser fore-end no longer crosses either focusing barrel. A bored paired
  breech encloses both roots; the side indicator is seated on that housing.
- Narrow ST rotary/laser barrel walls use 8 sides; mortar tube uses 12.
  Longitudinal bevels are excluded so the intended facets remain economical.
- optimize_gltf.py performs index-only attribute-aware simplification using
  meshoptimizer v1.0 (MIT), commit 73583c335e541c139821d0de2bf5f12960a04941.
  https://github.com/zeux/meshoptimizer/tree/v1.0
  Build command/dependencies are in its header; pass --library /path/to/lib.so.
- The optimizer writes candidates to test-results/weapon-optimization/candidates.
  Run compare_optimized.gd and check_optimized_images.py before promoting only
  accepted candidates to refined/*.glb, then run import.gd and the native tests.
  Do not repeatedly optimize an already simplified GLB: rebuild from the
  source pipeline first. Editable .blend masters retain the detailed source.
- Node names, transforms, emission/motion extras and original vertex/normal/UV
  data are retained; only index selection changes. CS sights/control geometry
  is protected. No normal maps or runtime shader work were added.
- check_optimized_attributes.py verifies unchanged attributes and all visible
  protected CS triangles against the saved original; zero-area faces may go.
- Full 58-model counts and evidence: test-results/weapon-optimization/.
  Total 515616 -> 482555 triangles, 33061 saved (6.41%).
