# Weapon audio validation — 2026-10-15

Seven runtime weapon reports and the energy impact were reauthored from eight user-selected CC0 Freesound public HQ previews, plus the existing Tabasco firearm transient. Fourteen further isolated takes were prepared for future tiers. [Audition, recipes and MCP receipt](../../../audio/cq-weapons-20261015/README.md).

- **325 successful Audacity MCP calls**, including 22 master exports and eight layered mixes. Filtering, attack/tail fades, normalization and mono export were applied through the installed xDarkzx/Audacity-MCP server.
- **114 mixer/behavior checks passed** on Godot 4.7.2, Vulkan Forward+, Intel ADL-N; actual nonzero mixer capture, all report mappings, voice limits, resource formats and cue behavior.
- **17 actual CQ client integration checks passed**, including all nine weapon mappings through the spatial backend and ballistic/energy/ordnance impact selection.
- **45 runtime clips passed isolated PCK loading** without loose source WAV/Ogg files.
- Signal checks passed for **45 runtime and 14 reserve assets**, including hashes, finite/nonzero samples, DC/headroom, and click-free endpoints for newly authored clips. Existing loop seams also passed. The eight weapon/impact cadence mixtures remain below 0.96 peak before playback attenuation; largest peak is approximately 0.907 for the assault rifle. The audition uses a common 0.35 gain.
- All eight downloaded inputs matched pinned SHA-256 values. Python compilation and `git diff --check` passed. The frontier packager now explicitly removes the reserve directory, in addition to `.gdignore` preventing editor imports. No deployment package was rebuilt or deployed in this task.

The local Audacity 3.7.7 process crashed when the MCP requested closing the final empty project, after every master had already exported successfully. No audio was lost. The encoding step then completed independently from the verified exports; the authoring script now leaves its empty scratch project open. The receipt contains the 325 successful authoring calls, with no fabricated cleanup success.

These are signal, import and integration checks, not a final headset listening review or multiplayer load test. The runtime voice budget, weapon timing, detection/audibility radii and gameplay rules are unchanged. No live service was modified.
