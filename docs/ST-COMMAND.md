# ST PDA and remote controls

Implemented in `experimental/st-raindance`, 29 September 2026. This work stays
outside the current release. Matching experimental clients and server use
protocol `fpsloppa-71-native-special-trace` following the [main integration](ST-MAIN-INTEGRATION.md); previous ST demo schemas remain readable.

## Controls

Open **COMMAND PDA** in the carried weapon wheel in VR, or press **C** on
desktop. A command station also opens it. The VR panel follows the offhand;
point the dominant controller and press its trigger to select. The movement
stick pans the map. Desktop uses left click, right-drag to pan and the mouse
wheel to zoom. Both views have zoom, centre, names and sensor-range controls.
Use, C/Escape or the VR weapon-wheel button closes the PDA. Ordinary weapon and
movement inputs are suppressed while it is open. The headset camera stays put.

The map incrementally surveys static terrain with 64 rays per update, caching
a 64×64 height/shading grid until the map changes. It shows friendly units and
equipment, both public flag positions and enemies currently known to the team
sensor network. Disabled equipment is grey. This is a coarse terrain map, not
an interior floor plan or a second full-scene renderer.

Select an ally and **FOLLOW** to accept them as commander. Commanders select
their units, choose **MOVE**, **ATTACK** or **DEFEND**, then click a destination.
Humans acknowledge with **ACCEPT**, **DONE** or **DECLINE**; **UNFOLLOW** clears
the relationship. Desktop Shift-click adds units to selection. Unassigned bots
accept an order and commander immediately. Self-orders create personal waypoints.
Accepted human orders show a world waypoint. Orders expire after three minutes
or on death, respawn, team change or lost command relationship. Bot orders use
the existing objective planner; carrying, catching or urgently recovering a
flag retains priority. Attack is a destination with normal combat, not a forced
target lock; defend holds the destination until cancellation or expiry.

The PDA **EQUIPMENT** tab lists team devices. Select an active camera or turret
and choose **CONTROL SELECTED**. The inventory's **SENSOR NETWORK → REMOTE
CONTROLS** page provides the same deployed-device access; **BASE TURRETS**
retains fixed defence control. Mouse movement or the dominant controller aims;
the fire input fires turrets. Cameras only rotate. Use/Escape releases control.
Video appears on a bounded desktop/VR panel. Passive camera watching remains
available separately in the sensor menu.

## Authority and adaptation

Only one operator can claim a device. The server checks team, operational
health/readiness, map epoch and player life. Mounted players and flag carriers
cannot claim devices. Switching devices releases the previous claim, including
fixed turrets. A one-second initial lease becomes 0.6 seconds once aim packets
arrive; lost input, death, disconnection or disabled/destroyed equipment releases
control. Turrets retain their actual capacitor, shot cycle, projectile and damage
rules. Blocked input cannot keep firing. Operator aim is replicated and drives
the head model on both hosts and clients.

Commands validate hierarchy, team, life, sequence, request rate, unit count and
finite in-map destinations. Humans must voluntarily join a command hierarchy;
cycles and enemy orders are rejected. Older recordings reset the new state.

The original manual's PDA/commander chapter informed hierarchy, sensors, orders
and remote operation (local research copy:
`test-results/st-vehicle-design/references/manual.txt`). Portable remote access
preserves this project's existing fixed-turret interface; it is an adaptation
of the original command-station restriction. Teammate cameras, explicit repair
orders, objective briefing, box selection and detailed interior maps remain
outside this first pass. Human headset ergonomics and contested command tactics
still need playtesting.

## Vehicle correction

All VR craft use turning-stick up/down for independent lift/descent, with
centred hover. Scout rockets aim with the dominant controller, regardless of
two-hand support or cosmetic hull pitch. Forward travel pitches the visual hull
slightly down. Ascent pitches it slightly up only with no horizontal input and
less than 1 m/s of residual horizontal drift. Desktop flight controls are retained.

## Validation

632 assertions passed across the command, both-handed VR/Vulkan, inventory,
deployable, parity, vehicle and recording suites, including 22 assertions in a
four-process local ENet test. That network test covers exclusive camera control,
aim replication, turret firing, follow/order/acknowledgement, rejected enemy
actions and loss-of-command release. Screenshots were inspected for desktop/VR
map layout. Logs contain no script errors; existing fixture-shutdown ObjectDB
and XR hand-resource UID fallback warnings remain.

The first network fixture incorrectly omitted dedicated-server mode/loadout
configuration; it then sent acknowledgement inside the command rate limit.
Both setup errors were corrected before the successful complete run. A core
test invocation with `--no-bots` was also corrected: its bot-planner assertion
requires the standard fixture bots.

```sh
godot --headless --xr-mode off --audio-driver Dummy --path . --script deathmatch/tests/st_command.gd
godot --xr-mode off --audio-driver Dummy --rendering-method mobile --rendering-driver vulkan --path . --script deathmatch/tests/st_command_vr.gd -- --vr-test --no-bots
python3 tools/tribes/test_command_network.py
```

Evidence: `test-results/st-command`. Tracked receipt:
[st-command-2026-09-29.json](validation/st-command-2026-09-29.json).
An empty Raindance session was refreshed in actual WiVRn/OpenXR with Vulkan;
startup confirms Quest Pro, XR readiness and map load. This confirms launch,
not human validation of the new controls.
