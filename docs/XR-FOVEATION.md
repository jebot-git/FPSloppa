# Foveation and quad views

Analysis and implementation: 2026-09-26, Godot 4.7.2, Vulkan Mobile.

## What the existing settings actually did

The project requested medium native OpenXR foveation with dynamic strength.
The VR rig enabled `Viewport.VRS_XR` only on Android; PC always used
`VRS_DISABLED`. Enabling eye-gaze interaction for avatar eyes did not override
that PC viewport policy. There was no saved graphics control for foveation.

Godot's `foveation_dynamic` adjusts **strength with workload**, between low and
the configured maximum. It does not mean eye-tracked rendering. The native
runtime profile and the generic VRS map are also different paths: the latter
uses `vrs_min_radius` and `vrs_strength`, not the native profile's level.
[OpenXRInterface API](https://docs.godotengine.org/en/stable/classes/class_openxrinterface.html).

## Graphics control implemented

**Settings → Graphics** shows one foveation control, chosen by the initialized
OpenXR runtime's eye-gaze capability:

- **VR Static Foveation: Off / Low / Medium / High** without eye tracking.
- **VR Fovea Size: Off / Small / Medium / Large** when eye tracking is supported.

The controls replace each other in the same position. Capability changes are
checked every half second, including while the Graphics page is open. A blink or
brief invalid gaze sample does not change the control or overwrite preferences;
The generic Vulkan gaze path switches to full-rate shading when gaze is invalid;
native density-map behavior remains runtime-owned.

Both choices persist independently in `deathmatch.cfg` and apply immediately.
Desktop rendering and simulated VR are unaffected. Defaults remain Off on PC and
Medium on Android. Existing configs migrate their previous strength to an
initial size: Off → Off, Low → Large, Medium → Medium, High → Small. Later changes
to static strength leave the saved gaze size intact, and vice versa. Session
start and capability changes reapply the applicable saved choice.

| Static preset | Native runtime profile | Generic VRS minimum radius / strength |
| --- | --- | --- |
| Off | Allocation retained, not applied to viewport shading | VRS disabled |
| Low | 1 | 55% / 0.5 |
| Medium | 2 | 40% / 1.0 |
| High | 3 | 25% / 1.5 |

| Gaze size | Native runtime profile | Generic sharp radius / peripheral rate |
| --- | --- | --- |
| Off | Allocation retained, not applied to viewport shading | VRS disabled |
| Small | High (3) | 25% / 2×2 |
| Medium | Medium (2) | 40% / 2×2 |
| Large | Low (1) | 55% / 2×2 |

On generic VRS, gaze size changes only the radius of the full-quality region;
peripheral strength remains fixed. Native runtimes expose coarse foveation
profiles rather than an exact radius, so the menu describes size as a preset
request. Native and generic settings are not measured equivalents. Percentages
for gaze are relative to half the view height, corrected for aspect ratio;
these are not headset field-of-view angles.

Manual levels disable workload-adaptive strength. Eye-tracked movement remains
independent and is still available: `foveation_eye_tracked` and the eye-gaze
interaction extension are enabled, and the action map already supplies
`eye_gaze_pose`. Where native foveation is supported, its profile is updated;
otherwise `gaze_vrs.gd` submits a persistent stereo `Texture2DArray` using
`VRS_TEXTURE` on GPUs supporting attachment VRS. The no-eye static path keeps
Godot's `VRS_XR` map. Runtime-profile setters are not called on
unsupported runtimes. Off disables viewport VRS. A nonzero native profile is
retained only to keep the Vulkan swapchain density-map allocation available.
Godot creates that allocation only with a nonzero profile; setting zero before
startup or a resize can otherwise prevent a later Off→On transition. The project
keeps its initial native level at 2 for that reason. Subsampled images remain
disabled. This is specific to the project's Vulkan renderer, not an OpenGL policy.

For a headset without eye tracking, this is **static foveation**. For generic
VRS with valid gaze, the application projects the forward `-Z` gaze ray at
10 m through each eye's current view/projection. Each layer has its own center;
positions are quantized to a 128×128 grid and updated only when needed. The
full-rate circle is surrounded by 2×2 shading, with no 4×4 region. Losing focus
or valid gaze fills both masks with full-rate shading. Native eye-tracked density maps
additionally depend on the runtime's relevant extensions and tracking support.
Eye hardware, avatar eye animation, and an advertised gaze extension alone do
not prove that a native eye-tracked density map is active. The menu describes
requests and capabilities rather than claiming measured activation.

`XR_FOVEATION` logs the active mode, both saved choices, applied profile level,
generic radius/strength, interface readiness, native-profile support, retained
native profile level, gaze support, view count and viewport VRS mode when settings change.
It does not log gaze samples. Unsupported GPUs may ignore the VRS request.

The 2026-09-27 WiVRn test uses a separate desktop eye mirror showing the actual
submitted left-eye mask: green for full rate, red for 2×2. The launcher and overlay
are under export-excluded `test-results/`; they do not render into the headset
and are not release features. The additional desktop render has a performance
cost, so its frame rate is not a clean headset-only performance measurement.

## Quad-view conclusion

**The current build cannot render quad views.** Inspection of the local engine
source in `Builds/ServerRuntime/godot-4.7.2-stable` found:

- `modules/openxr/openxr_interface.cpp`: `get_view_count()` returns 2.
- `servers/rendering/renderer_scene_render.h`: `MAX_RENDER_VIEWS` is 2.
- `modules/openxr/openxr_api.cpp`: quad-view configuration selection is commented
  out as unsupported. `get_eye_focus()` implements the stereo gaze fallback.
- `modules/openxr/extensions/openxr_fb_foveation_extension.cpp`: native profile
  configuration and eye-tracked density offsets are separate from quad views.

Quad views need two context views plus two narrower focus views. Focus views can
follow gaze while context views retain peripheral coverage. Different view
resolutions require separate render targets and appropriate composition. Varjo
requires applications to opt into the quad-view configuration; its foveated
rendering extension additionally enables gaze-dependent projections.
[Varjo OpenXR graphics](https://developer.varjo.com/docs/openxr/graphics).

This cannot be enabled by changing a project integer or adding two cameras.
Godot's [multi-layer rendering proposal](https://github.com/godotengine/godot-proposals/issues/12572)
describes the needed 2+2 rendering, projection, viewport and shared-culling
changes. An implementation would also need correct swapchain submission,
per-view visibility/MSAA, shaders and HUD handling, plus testing of stereo
fallback and tracking loss. FPSloppa's eye-dependent scope and view-index shader
assumptions would need auditing against the chosen engine implementation.

The [Quad-Views-Foveated layer](https://github.com/mbucchia/Quad-Views-Foveated/wiki)
can adapt applications that already implement quad views. It cannot supply
missing engine support to this game. No layer has been installed and no
nonfunctional quad-view toggle has been added.

## Validation and practical settings

Start at Low on a PC headset without gaze, then compare Medium at the same
resolution, refresh rate and MSAA. Keep the lowest level that gives useful GPU
headroom while preserving peripheral enemies, crosshairs and HUD text. For
eye-tracked headsets, also test rapid saccades, calibration, permissions and
temporary tracking loss. A reduced shading rate primarily targets GPU pixel
cost; it does not fix CPU spring-bone work, physics stalls or network rubberbanding.
[Godot VRS documentation](https://docs.godotengine.org/en/stable/tutorials/3d/variable_rate_shading.html).

Validated locally:

- `deathmatch/tests/foveation.gd`: native/generic and gaze/no-gaze policy,
  Off→On transitions, independent gaze/static choices, legacy migration,
  size ordering, inactive runtime, stable profile writes and malformed preferences. Runtime capabilities are simulated in this test.
- `presentation.gd` and `client_preferences.gd`: actual button cycling, saved
  values, runtime-dependent control replacement, desktop/headset-free handling
  and scroll access on the VR canvas.
- Native Vulkan Graphics-page capture on Intel Arc A770; layout inspected.
- Dedicated-server package build and automated server regression checks.

The broad `export_resources.gd` asset audit could not run to completion because
its optional cached `maps/cache/lqdm4.scn` fixture is absent locally. This is
separate from the foveation tests and the successful server package audit.

No eye-tracking headset, native OpenXR density map or quad-view session was
hardware-tested. No FPS improvement is claimed. Validate runtime GPU timing,
missed/reprojected frames and image quality on the target Windows/SteamVR,
standalone and streaming setups before making performance claims.
