# Weapon and animation frametime improvements

Implemented the first three proposals from the [frametime study](CPU-FRAMETIME-STUDY.md). The existing distance thresholds and conservative XR LOD policy remain unchanged.

Weapon decoration is cached in up to 64 packed visual templates. Imported subscenes are flattened before packing so clones neither duplicate geometry nor leak orphan nodes. The selected arsenal and Quake TF replacements are prepared during map loading; equip creates an instance of the prepared visual. CS weapons retain their existing scene cache and construct independent chamber/reload actions. Transforms, visibility and action state remain per-instance, while meshes and materials can be reused. First-use preparation moves to loading; it is not eliminated.

Missing avatar clips now enter a bounded queue with weak references to their requesting rigs. A single global slice performs at most two of the 21 pose samples per process frame. Each slice restores the live skeleton, locomotion, tracking, recoil, pain and solver state before returning. Completed clips are shared by avatar and locomotion key, and the previous valid animation remains active while another clip is prepared. Dead or removed requesters are discarded. This is incremental in-memory preparation, not a disk cache or work performed on the live scene tree from a worker thread.

Remote IK now interpolates between solved poses at display cadence, including tracked wrist positions. Expensive IK retains its existing cadence. Prepared generic clips use native animation-track interpolation every render frame. Teleports, death/respawn, waking, tracked/untracked transitions, weapon changes and handedness changes invalidate stale blends. First-person tracked poses remain immediate. Remote interpolation can add up to one existing solve interval of cosmetic delay, approximately 33–67 ms for budgeted poses; hitboxes and authority are unchanged. Pickup bobbing also uses a cosmetic render clock instead of stepping with the physics clock.

## Measurements

Repeated weapon construction, native Vulkan Mobile on the same i7-12700 / Arc A770:

| Loadout | Before median | After median | Before maximum | After maximum |
| --- | ---: | ---: | ---: | ---: |
| Doom | 0.081 ms | 0.060 ms | 13.909 ms | 0.153 ms |
| Quake | 13.776 ms | 0.107 ms | 16.161 ms | 0.177 ms |
| UT99 | 13.756 ms | 0.110 ms | 14.490 ms | 0.223 ms |
| CS 1.6 | 0.126 ms | 0.130 ms | 1.019 ms | 0.769 ms |

These are factory CPU timings, not first-visible-frame GPU pipeline timings. The cold first pass and all individual samples are retained in the receipt.

The focused fixture observed a maximum live clip slice of **0.61 ms**, including job initialization; the earlier full synchronous bakes took approximately **1.91–2.15 ms**. Slice duration depends on the avatar and scheduling; the enforced limit is two samples, not a hard real-time microsecond deadline.

Interpolation has a steady cost. For 16 avatars, average instrumented rig + pose + eye script time changed from 2.70 to 2.80 ms near the camera, 0.69 to 0.79 ms with distant desktop LOD, and 1.40 to 1.62 ms under the synthetic distant XR policy. Morph timing is nested inside eyes and is not added again.

The synthetic XR-policy scene's wall-frame p95 increased from 7.58–7.67 to 8.96–9.23 ms in the paired blocks. Near-scene p95 was 8.65–8.96 before and 8.93–9.01 ms afterward; distant desktop p95 was 6.32–6.90 before and 6.31–6.54 afterward. These runs do not control clocks or scheduling, and the instrumented script scopes exclude native skeleton work. The result supports a large reduction in weapon-build stalls and smaller clip-preparation slices, not an across-the-board FPS improvement. No physical headset performance claim is made.

## Validation

- 2,379 focused checks: cached geometry/tints/muzzles, independent CS actions, orphan-free retirement, interpolation/reset behavior, immediate local poses, per-frame distant playback, sliced/reference clip parity, live-state restoration and canceled requests.
- 702 existing animation checks and 1,081 headless / 1,082 rendered LOD checks passed.
- TF visual replacements, CS reload UI, local tracer origins, shared combat/haptics, death poses, weapon setup, rendered motion and the cached weapon gallery passed.
- Reviewed the rendered weapon gallery and close/distant avatar captures. Physical headset feel remains untested.

Some existing test fixtures were updated for already-current APIs/settings: generated audio attenuation, enforced TF loadout, defusal visibility and opt-in spring simulation. Successful standalone fixtures still report the existing ObjectDB shutdown warning. New cached weapons leave no orphan nodes.

[Full receipt and benchmark samples](validation/frame-smoothness-2026-09-28.json).
