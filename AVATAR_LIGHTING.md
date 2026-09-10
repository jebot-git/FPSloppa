# VRM lighting in the arena

VRM MToon materials now opt into an arena lighting response during rig setup. A small texture-coloured fill keeps silhouettes readable in dim areas. Directional and local point lights still affect shading and colour, but their accumulated contribution is limited. Strong authored emission, matcap and unlit rim contribution are also bounded so a custom VRM cannot appear as a uniformly glowing silhouette simply because of its material settings.

The shader retains the imported base/shade textures, alpha mode, UV transforms, normal maps, toon shading, skinning and blendshapes. Material-colour/UV animation paths remain valid. Local player body views, the model preview and remote avatars use the same policy. Spy disguises receive it through the normal VRM importer; the cloak override still takes precedence and reveal restores the prepared original material.

Ordinary glTF/PBR materials (including imported unlit ones) use per-pixel lighting with restrained metallic/specular response. Non-emissive materials get a small albedo-coloured fill; existing emission is reduced while retaining its mask. Unlike MToon, this fallback retains standard Godot lighting and does not have a strict accumulated-light clamp.

No per-avatar point light, extra outline pass, per-frame environment raycast or full-screen effect is added. Existing map, projectile and muzzle lights can influence the models where those effects create real Light3D nodes; emissive textures alone are not global illumination. The generated map bake illuminates static surfaces; moving avatars continue to use the live lights and bounded fill. The small fill is intentionally independent of local lights, so this does not promise physically accurate darkness or full bounced lighting.

`deathmatch/tests/avatar_lighting.gd` renders all three default VRMs in dim, strong white, warm and cool lighting. It measures visibility, near-white clipping and colour response. `fortress_visuals.gd` verifies the spy's actual VRM swap, cloak and material restoration. Hardware frame-rate testing is still required; automated rendered checks do not establish Quest/Pico or PCVR performance.

The change to `addons/Godot-MToon-Shader/mtoon_common.gdshaderinc` is opt-in (`_ArenaLightingEnabled` defaults false), retaining the upstream shader behavior for other uses. Upstream license notices are unchanged.

The extended cloak render fixture can leave a Godot worker-thread shutdown warning. Its assertions pass; continuous-session memory usage has not been certified by that test.
