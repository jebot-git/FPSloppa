# ST wrist interfaces

The tactical PDA and remote camera/turret feeds use an offhand wrist computer in
VR. They follow the grip's complete transform, including forearm roll, and move
to the other wrist with the dominant-hand setting. The mount uses the same
OpenXR grip-to-anatomical-hand mapping as avatar hands; head movement does not
rotate the display. Desktop interfaces remain available.

Following headset feedback, the screen and casing turn 60° sideways, mirrored
between wrists, and sit 4 cm farther out from the forearm. The cuffs keep their
forearm alignment; four extended brackets connect them to the raised casing.

The compact tablet casing has a raised bezel, opaque back, rear vents, fasteners
and two cuffs. Its original geometry was finished in Blender through MCP and
exported as compressed Godot-native scenes. Cases load on first use and share
their resources. A visible device uses a cuff mesh, casing mesh and screen quad;
existing PDA/camera viewports are reused.

PDA pointing and trigger selection retain their existing hit targets. Rays from
behind the case or outside the actual screen cannot activate controls. Loss of
XR focus/tracking hides the wrist display, and a hidden remote display cannot
continue firing. Closing either interface hides its case as well as the screen.

Camera/turret feeds now contain their own reticle, live indicator, device title
and disconnect hint, so these appear on the wrist screen too. Remote and scope
cameras exclude the tablet's local rendering layer, preventing video feedback.

## Validation

`deathmatch/tests/st_command_vr.gd` passes 88 checks with Vulkan, simulated VR and
`--capture-wrist`. This covers both dominant hands, wrist translation/roll,
anatomical orientation, head-independent placement, PDA pointer/trigger input,
front/back/bezel ray rejection, focus handling, camera and deployed-turret input,
release cleanup, desktop PDA controls and the existing Scout input checks.

Blender front/back views and engine captures were inspected. Evidence is in
`test-results/st-wrist-display`; the machine-readable receipt is
[st-wrist-adjustment-2026-09-29.json](validation/st-wrist-adjustment-2026-09-29.json).
Existing fixture shutdown resource warnings remain; the final run contains no
script errors or failed assertions. The user confirmed the interface functions
passed the initial headset test; the adjusted wrist pose still needs headset
comfort confirmation.

Base-turret firing audio now uses each turret's weapon cue. When a player is
operating a distant turret, that cue is relayed at the wrist screen (or desktop
camera) so it is not lost beyond the spatial mixer's 80 m range. Other listeners
hear it at the actual muzzle. The operator receives only one cue per shot.
The updated Vulkan VR suite passes 101 checks without capture-only assertions,
including the five turret families, distant operator audio, world audio and
stale-event rejection. The existing turret/combat suite passes 94 checks.
