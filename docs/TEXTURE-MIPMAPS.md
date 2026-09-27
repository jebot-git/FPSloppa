# Texture mipmap policy

Texture imports generate the complete mip chain (`mipmaps/generate=true`,
`mipmaps/limit=-1`). Project defaults cover new images; checked-in runtime
`.import` files preserve the policy for existing art. The three controller normal
maps explicitly use normal-map import processing, rather than waiting for editor
auto-detection. `tools/mipmap_imports.py --fix` migrates older local import files.

Runtime preparation covers all BaseMaterial3D texture slots, shader image
parameters (including VRM `_BumpMap` and mask maps), secondary passes, overlays,
sprites, particle meshes and decals. Missing normal mip levels are generated with
vector renormalization. Preparation copies the source image so shared colour and
normal bindings cannot overwrite each other's pixels. Verified textures are
marked to avoid repeat GPU readback on subsequent asset loads. Settings changes
continue to select existing sampling variants without preparing pixels.

Map colour textures retain the existing linear-light mip generation, preserved
level zero and alpha-cutout coverage handling. Map preview images and weapon
wheel icons now have both mip levels and mip-enabled UI filtering. All MToon
visual samplers, including normal and mask textures, explicitly use anisotropic
mipmap filtering. Its include-based samplers still use fixed anisotropic
filtering independently of the graphics-menu filter selection.

Packed BSP lightmaps intentionally retain bilinear sampling without mipmaps:
their one-luxel atlas gutters cannot isolate faces at smaller mip levels. The
weapon-light BSP lookup texture stores exact floating-point data and remains
nearest/texel-fetch sampled. Live viewport textures (menus, scopes and cockpit
surfaces) keep their own render-target sampling. A 1×1 texture needs no smaller
level. These are deliberate exceptions, not missing visual mip chains.

## Validation — 2026-09-26

Godot 4.7.2, Vulkan Mobile, Intel Arc A770. Loaded-image inspection found no
incomplete visual mip chains:

| Asset group | Assets | Texture chains checked |
| --- | ---: | ---: |
| Runtime image imports | 87 | 87 |
| Installed maps (including all five DE maps and Cindercoil) | 36 | 705 |
| Weapon, pickup, vehicle and XR hand scenes | 74 | 94 |
| Available VRMs (three bundled, seven local) | 10 | 112 |

Textures are deduplicated within each asset, not across separate assets. Optional
maps absent from this installation are not claimed as tested. The import-policy
audit additionally checked 635 local developer textures excluded from exports:
722 import files total, zero missing settings. A fresh 17×9 PNG in an isolated
project inherited the defaults and generated all four lower levels.

Targeted mipmap, retained-filter, colour/alpha, preferences and map-presentation
tests passed. The rendered filter-switch profile recorded 16 samples with zero
image reads and zero texture rebuilds. All 17 rendered reload-presentation checks
passed, including controller and pouch initialization; the captured pouch/USP
view was inspected for missing textures. See the
[validation receipt](validation/mipmaps-2026-09-26.json).

The broader `post07.gd` suite passes its texture check but retains an unrelated
legacy aim-guide assertion: it expects a beam shorter than 25 cm at the unscaled
muzzle, while the existing guide uses a 60 cm beam, VR scaling and a 4 cm start
offset. Both the assertion and guide constants predate this change.

Reproduce:

```sh
python3 tools/mipmap_imports.py
godot --headless --xr-mode off --path . --script deathmatch/tests/mipmaps.gd
godot --xr-mode off --rendering-method mobile --path . --script tools/audit_mipmaps.gd
godot --xr-mode off --rendering-method mobile --path . --script deathmatch/tests/filter_switch_profile.gd -- --baked-fixture --profile-output mipmaps-filter-switch.json
```

Godot 4.7.2's `Texture2D.has_mipmaps()` returns false for ImageTexture even when
its image has a full chain. The audits therefore inspect `get_image()` and count
the actual levels; they do not infer success solely from import settings or that
texture method. Existing XR-tools UID fallbacks and the engine's ObjectDB exit
warning remain; no shader or script errors occurred in the mipmap asset audit.
