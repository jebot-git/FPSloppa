# Desktop scope input, weapon mix and ambient settings

The fullscreen scope texture ignored mouse input, but its parent Control used the default STOP mouse filter. That parent consumed motion before the arena unhandled-input aim handler could receive it. The parent now also ignores mouse events. The existing live aim, elevation limits and VR controller aim are unchanged.

The vehicle-view regression now delivers real viewport mouse motion through the visible overlay for light, heavy and rocket tanks instead of only assigning yaw/pitch directly: 82 checks pass, including VR controller aim and transport interpolation coverage.

CQ infantry and vehicle weapon reports receive 6 dB more gain. Infantry reference distance increases from 2 to 5 metres; vehicle reports use 8 metres. Godot and Steam Audio use the same reference distance. Scout suppression retains its lower level and short audible radius; existing remote culling, occlusion, engine loops and ambience levels remain unchanged. Field audio suite: 151 checks pass across 50 assets. Subjective loudness should be checked on the player's output device.

Ambience uses the common minus/plus volume stepper at five percent per press, with immediate application, persistence and percentage display. Sound effects is labelled separately. CQ menu suite: 65 checks pass, including real ambient button presses and all page layout checks at 960 by 640. The captured Audio page is included here.

Commands:

```
Godot --path . --xr-mode off --audio-driver Dummy --script deathmatch/tests/cq_vehicle_view_motion.gd
Godot --headless --path . --xr-mode off --audio-driver Dummy --script deathmatch/tests/cq_field_audio.gd
Godot --path . --xr-mode off --audio-driver Dummy --script deathmatch/tests/cq_menu.gd
```
