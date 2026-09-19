# Occlusion for emissive projectile illumination

Current implementation: [weapon matrix and live map integration](WEAPON-EMISSION.md). The report below records the earlier isolated feasibility experiment.

19 September 2026. **A tested solution is to trace each illumination segment through BSP solid space, using a conservatively shortened tree for each emitter.** It fixes the reproduced wall leakage without realtime light nodes, screen-space depth or lightmap rebakes. This remains an isolated prototype; production weapon effects are unchanged.

Follow-up: [avatar receiver tests](AVATAR-TRAJECTORY-LIGHTING.md) demonstrate the contribution on three MToon VRMs and the placeholder, including BSP wall rejection. Avatars casting shadows remain outside that experiment.

## Method

The project already parses Quake BSP planes, nodes and contents in `deathmatch/maps/contents.gd`. The prototype serializes the tree into an RGBA32F texture: one plane and one child-index record per node, with solid/sky leaves marked blocked. This is 44 KiB for DM6's 1,322 nodes and 52 KiB for Vesper's 1,545 nodes.

For a surface that falls within an emitter's range and faces it, the shader traces the segment from the surface to the closest point on the trail. It splits the segment at BSP planes and rejects illumination whenever any traversed interval lies in solid space. This checks geometry independent of the camera, including a blocker hidden behind the wall being viewed. A zero-length trail still works as a bullet emitter.

This is analytic intersection, not fixed-step sampling through a voxel grid, so the test does not step over a 2 cm wall. A 2 mm surface-normal offset avoids self-occlusion. Traversal has a 32-entry stack and 192-visit limit; exhausted bounds reject illumination instead of leaking it. Surfaces or gaps comparable to the offset, pathological BSP complexity and extreme world coordinates need separate validation.

The unoptimized implementation pays for the whole tree at every affected pixel. The selected optimization prunes branches against each trail's influence AABB, enlarged by 4 mm to include the surface offset. A plane can be omitted only when the complete AABB is on one side; equal children collapse. Both ray endpoints and their connecting segment are inside this convex domain, so the retained tree gives the same answer there. Tested screenshots are byte-identical to the full-tree result. The moving eight-emitter benchmark rebuilds these small trees each frame, including upload cost; it does not rely on stale visibility.

Moving brushes are separate tree roots plus inverse transforms. Rays are transformed into brush-local coordinates; pruning uses a conservative transformed bound. Closed, translated-open and rotated door fixtures work with both full and shortened trees. The prototype supports four registered moving roots. Actual game doors/platforms still need their BSP model roots and current transforms wired into this pool. Static map tests use the world root only.

## Validation

**52 checks pass. 3,072 GPU visibility queries agree with independent physics raycasts, with zero leaks and zero false blocking.** The queries cover six fixtures, two maps, and full/pruned/convex-cell representations of the map regions. Query start points inside colliders are excluded because physics surface raycasts and BSP solid-content tests have different semantics there. The selected pruned path also matches full-tree images byte-for-byte in both maps and all five visual wall/door cases.

| Case | Result |
| --- | --- |
| Original divider wall | Hidden floor returns to baseline; visible floor stays lit |
| 2 cm wall | Blocks illumination without stepping over the wall |
| 2 cm ceiling/floor slab | GPU vertical/oblique visibility agrees with physics |
| Closed door | Blocks light |
| Raised/open door | Restores illumination across the opening |
| Rotated door | Correctly blocks in its transformed position |
| Quake DM6 and TF Vesper | Correct map visibility with both existing BSP shader paths |

At the blocked floor probe, the unoccluded effect increases the red channel by 0.173; corrected illumination adds exactly 0.000. The unblocked probe still gains 0.165. Opening the door restores the original 0.173 gain. No realtime light nodes exist in the loaded map scenes. Comparison images were inspected visually. Godot reported one ObjectDB instance cleanup warning at exit; no shader errors or failed checks occurred.

## Cost and selected approach

Arc A770, Godot 4.7.2 Mobile/Vulkan, 1280×720, 4× MSAA. Twenty 400-frame blocks measure 8,000 frames, with a three-second map warmup. The table compares the selected pruned-tree implementation to the same trail illumination without occlusion. For repeated settings it averages block medians; these are view-specific desktop measurements, not headset budgets.

| Map | Emitters | Without occlusion | With occlusion | Added GPU | Script update |
| --- | ---: | ---: | ---: | ---: | ---: |
| DM6 | 1 | 0.144 ms | 0.415 ms | 0.271 ms | 0.074 ms |
| DM6 | 4 | 0.232 ms | 1.403 ms | 1.171 ms | 0.128 ms |
| DM6 | 8 | 0.350 ms | 2.690 ms | 2.340 ms | 0.204 ms |
| Vesper | 1 | 0.206 ms | 0.257 ms | 0.051 ms | 0.079 ms |
| Vesper | 4 | 0.295 ms | 0.384 ms | 0.089 ms | 0.095 ms |
| Vesper | 8 | 0.381 ms | 0.559 ms | 0.178 ms | 0.119 ms |

All blocks retain nine median draw calls. Script update includes projectile transforms, tree pruning and texture/parameter updates. GPU and CPU costs are reported separately and should not simply be added to predict frame latency. DM6's close corridor covers much more of the screen with affected surfaces, illustrating the fill-rate and scene-dependence of this method.

The full-tree version measured roughly 3.96 ms total GPU time at eight emitters in DM6 in the earlier run. A second implementation flattened local solid leaves into convex clipping volumes to avoid a traversal stack. It passed visibility tests but measured about 7.02 ms total in DM6 and 0.65 ms in Vesper at eight emitters, so it is retained as a diagnostic alternative and **not selected**. Receipts for both earlier experiments remain in the result directory.

The practical next implementation would begin with one or two nearby emitters, short ranges and priority/fade rules. Eight fully occluded trails are too costly to enable universally based on these measurements. Test real weapon speeds, network interpolation, crowded fights and the actual headset before choosing production limits. No comparison against shadowed engine lights was performed, so this is not evidence that custom occlusion is cheaper than those lights.

## Integration limits

- Only the closest point on the trail contributes. If it is occluded while another part is visible, the effect can under-light the surface; this is not physically integrated area lighting.
- Surface shaders still need explicit receiver support. Avatars, arbitrary imported meshes, transparent surfaces and non-BSP dynamic occluders are outside these tests.
- Map submodels and runtime geometry must be registered with their transforms. The fixture proves the transformed-root mechanism, not automatic hookup to every game entity.
- Treat liquid/sky/clip/illusionary contents according to a deliberate visual policy. This probe blocks solid and sky leaves, allows liquid leaves, and has not validated alpha-tested fences.
- Source validation, acyclic tree checks, aggregate CPU pruning budgets, cache identity and allocation reuse are required before accepting arbitrary uploaded maps in this path. The bounded shader fails dark on excessive complexity; that alone does not bound CPU preprocessing of malicious input.
- Preserve impact clipping from projectile simulation. Occlusion prevents an emitter inside solid from lighting through it, but does not fix a cosmetic tracer drawn past an impact.

## Artifacts and reproduction

`test-results/trajectory-occlusion/comparison.jpg` shows the original leak, 2 cm wall and DM6 before/after. `door-comparison.jpg` shows the corrected closed/open response. Durable measurements are in `docs/validation/trajectory-occlusion.json`.

```sh
godot --xr-mode off --path . --rendering-method mobile \
  --log-file /tmp/occlusion-engine.log \
  --script res://tools/lighting_experiment/trajectory_occlusion_probe.gd
python3 tools/lighting_experiment/occlusion_report.py
```

Add `-- --cells` to the Godot command to benchmark the slower convex-cell alternative. The probe uses in-memory shader variants; production shaders and BSP assets are untouched. Its texture fetches, uniform arrays and bounded local stack use Godot's documented [shader language facilities](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html).
