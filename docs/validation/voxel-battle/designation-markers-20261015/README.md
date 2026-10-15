# Designation guides and spotted markers — 2026-10-15

[Behavior and range details](../../../CQ-DESIGNATION-MARKERS.md). [Rendered marker preview](markers.png).

- **53 checks passed** in `deathmatch/tests/cq_designation_markers.gd`: current T1 launch parameters and 200 m arc; trajectory integration; all eight supported direct-fire weapon slots and out-of-range rejection; technician/tool eligibility; light/heavy shell lifetime; rocket-tank reach; driver versus passenger eligibility; skipping unreachable/expired/enemy designations; actual world obstruction and fallback; four enemy class markers; occupied vehicle substitution; empty hull, cloak, allied and expired-memory suppression; marker teardown and all eight imported textures.
- **19 existing actual CQ client integration checks passed** after wiring the new services into the arena. The arena script parse check and editor import also completed without errors.
- **Eight marker textures loaded from an isolated PCK**, containing their import sidecars and generated textures without loose SVG sources.
- The 3D gallery was rendered using Godot 4.7.2 Vulkan Forward+ on Intel ADL-N, then visually inspected. Symbols and captions use constant screen size and contrasting backing.
- Python compilation and `git diff --check` passed.

Artwork is original CC0 and reproducible with the committed builder. This is client presentation work: no native authority/wire format changes, spotting-range changes, VPS deployment or multiplayer load benchmark were performed. The guide's path/range tests and marker visibility checks do not substitute for final VR headset ergonomics review.
