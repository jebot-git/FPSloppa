# Avatar receivers for projectile trail illumination

19 September 2026. **The effect works on the three tested MToon VRM avatars and the boxy placeholder, including BSP visibility rejection.** A further example places an illuminated VRM in the actual dark DM6 map. These are private diagnostic shader variants; the game has not enabled this feature.

## Implementation

MToon performs its own model-to-view vertex transform. The prototype captures world position and normal before that conversion, using the skinned vertex inputs. It preserves the rest of MToon's code, alpha handling, textures, arena fill, and existing outline/next passes. The additional light is texture-tinted and bounded to 0.55 per channel before multiplication by the material albedo. Normal/distance falloff and the previous BSP segment visibility routine determine the contribution. No `Light3D` objects are created.

The opaque placeholder uses a small shader adapter for its existing albedo, emission, metallic and roughness properties. The adapter is sufficient for its tested materials and matches the baseline exactly; it is not a universal conversion of all StandardMaterial3D features. Arbitrary PBR VRMs with normal maps, layered textures, transparency or special UV features require further support. The three VRM samples exercise MToon.

Each modified material is a private copy assigned as a mesh surface override. Original shaders/materials and their next-pass resources remain unchanged. Production integration must preserve the game's material ownership and expression bindings rather than blindly copying the diagnostic replacement procedure.

## Results

The graphical test passes **741 assertions**, including repeated per-surface checks for source-material isolation and unchanged next passes. The report also verifies full-image byte equality for the original, effect-off and wall-blocked renders of all four models.

- `sample_d`, `sample_f`, `sample_g`, and the placeholder all respond to warm and cool trail colors.
- The opaque BSP wall test removes the added light completely. The wall is represented in the occlusion texture but is not drawn over the model, so a matching dark image cannot be explained by hiding the avatar behind wall pixels.
- The three VRM skeletons receive illumination after explicit arm-bone pose changes. The fallback receives it after a crouch/gait pose change. Tests verify that both the pose and illumination change the rendered image.
- Moving the camera, model and emitter together by `(20, 4, -15)` preserves the illumination: mean channel differences remain below 0.000002 in the final run. Remaining maximum pixel differences are at most two 8-bit levels for the VRMs, zero for the placeholder.
- A posed `sample_d` in DM6 receives light with the actual world BSP tree bound to its shader. The map shader remains unchanged in this example, isolating the avatar's added response.
- No extra draw calls or white-clipping regression appeared. No realtime light nodes exist in the test scene. Godot emitted one ObjectDB cleanup warning at exit, with no script/shader errors or failed checks in the final run.

The comparison images and DM6 example were inspected visually. These are posed stills, not a live multiplayer or continuous animation playtest.

## Performance scope

Arc A770, Godot 4.7.2 Mobile/Vulkan, 800×800, 4× MSAA. Six 300-frame blocks per model measure 7,200 frames total, with emitter counts `0, 1, 4, 4, 1, 0`. Figures below average the two block medians relative to the same receiver shader with zero emitters:

| Model | Added GPU, one emitter | Added GPU, four emitters | Draw calls across settings |
| --- | ---: | ---: | ---: |
| sample_d | 0.002 ms | 0.049 ms | 3 |
| sample_f | 0.040 ms | 0.131 ms | 3 |
| sample_g | 0.075 ms | 0.173 ms | 3 |
| Placeholder | 0.002 ms | 0.011 ms | 13 |

These are isolated single-avatar views with an empty occlusion tree during timing. They measure the receiver calculation, not full-map BSP traversal, multiple visible players, changing animation or per-frame emitter upload/pruning. See [the occlusion assessment](TRAJECTORY-OCCLUSION.md) for scene-dependent visibility cost. Tiny differences are subject to GPU timing/clock variation. Headset and VR stereo performance remain untested.

## Remaining integration work

The tested avatars **receive** the trail effect. They do not become BSP occluders: character self-shadowing, one character blocking light onto another, and avatar shadows on the map are not implemented. The extra light uses geometric normals; the original material's normal-map shading remains, but is not sampled by this contribution.

Retain an explicit material policy for cloak/invisibility, frozen overlays, team colors, first-person head hiding, expression/blink/UV animation bindings, and non-MToon imports. Those runtime combinations were not validated here. Keep the prior small emitter budget recommendation; shared emitter data can serve both map and avatar receivers, but covering more pixels increases GPU work.

## Artifacts and reproduction

- `test-results/avatar-trajectory/comparison.jpg`: baseline, warm, cool and wall-blocked views for all four models.
- `test-results/avatar-trajectory/dm6-comparison.jpg`: avatar-only effect in the actual dark BSP map.
- `docs/validation/avatar-trajectory.json`: durable checks, image parity and measurements.

```sh
godot --xr-mode off --path . --rendering-method mobile \
  --log-file /tmp/avatar-trajectory-engine.log \
  --script res://tools/lighting_experiment/avatar_trajectory.gd
python3 tools/lighting_experiment/avatar_trajectory_report.py
```
