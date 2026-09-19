# Teleporter and portal exits

Teleportation now applies the exit position and facing together to the player, interpolation target and owning camera. It clears entrance velocity, blast knockback, pending jump, swimming and room-scale displacement. Delayed input from before the teleport is rejected until the owner sends the new life serial, so an in-flight packet cannot restore the entrance yaw or move the player back behind the portal.

Destination parsing accepts both Quake `angle` and `angles` yaw. VR exit facing includes the physical headset's local yaw, including full-body tracking, so a player who turned their head before entering still looks toward the exit. Host VR room-scale origin handling uses the same reset as a replicated spawn.

The shared exit resolver preserves valid authored positions and headings. A marker inside or just behind an upright portal moves forward beyond the actual trigger box plus player-radius clearance. Rotated portals are evaluated in their own coordinate frame. An immediately wall-facing heading can turn toward a clear departure direction. Capsule sweeps prevent the correction from crossing solid geometry; an obstructed destination is rejected. Bot navigation links use this same resolved destination. The existing telefrag, cooldown and sound behavior remains.

## Validation

- **24 focused checks:** authored cardinal/diagonal headings, scalar/vector map angles, wall-facing correction, front-side placement for straight and rotated portals, collision rejection, cleared momentum/input, delayed-input protection, fresh-input resumption and physical headset yaw.
- **23 ENet checks:** a server, owning client and observing client. The server deliberately withholds the teleport snapshot while the owner sends stale entrance input, then checks authoritative state, both replicas, owner camera orientation and resumed controls.
- **40 real destinations across 15 maps:** all existing authored positions and headings remain unchanged, capsule-clear, with at least one metre of forward walking clearance. This includes all 36 bundled exits plus Hektik and Toxicity from the installed build.
- Existing environment-feedback tests pass, including departure/arrival cues and demo events.

Results: [focused checks](../test-results/teleport-exits/focused.json), [map audit](../test-results/teleport-exits/maps.json), [network checks](../test-results/teleport-exits/network.json). VR orientation was checked through tracked-pose math; physical headset testing was not performed.

```sh
godot --headless --xr-mode off --path . --script res://deathmatch/tests/teleport_exits.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/teleport_maps.gd
python tools/run_teleport_network.py
```

Additional local BSP paths can be passed after `--` to the map audit. They are read in place; temporary imported scenes and test receipts stay under `test-results/teleport-exits`.
