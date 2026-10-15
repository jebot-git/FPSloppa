# CQ energy and projectile weapon audio

[Play the firing-cadence audition](runtime-cadence.wav). Reports are repeated at gameplay cadence, with a common preview gain and one second between families. The reel contains pistol, suppressed scout pistol, SMG, carbine, assault rifle, beam rifle, burst pistol and energy impact, in that order. [Exact timings](timings.json).

The ballistic family retains the recorded firearm transient, reinforced with a quiet sci-fi body; the scout pistol is quieter with a filtered tail. Energy weapons share a descending blaster character. The carbine has a fuller report, the assault rifle a tighter pulse, the beam a longer and heavier discharge, and the burst pistol a lighter plasma shot. Each runtime file contains one shot; game events supply the burst timing. Existing weapon mappings, audible radii, damage, magazines and rates of fire are preserved.

Eight supplied Freesound recordings are used, all marked CC0 on their source pages. The public HQ MP3 previews were used rather than authenticated lossless originals. [Credits and editing details](../../../deathmatch/audio/cq_field/SOURCES.md). [Pinned downloads](../../../tools/cq_audio/weapon_sources.json). [Layer recipes](recipes.json). [Successful Audacity MCP authoring calls](audacity-mcp-receipt.json).

Fourteen further takes are available in the [future-tier reserve](../../../tools/cq_audio/tier_reserve/README.md); they are not assigned or imported at runtime.

Reproduce with Audacity 3.x running and mod-script-pipe enabled:

```sh
/path/to/audacity-mcp-python tools/cq_audio/reauthor_weapons.py
# Or encode the existing Audacity exports:
/path/to/python-with-numpy tools/cq_audio/reauthor_weapons.py --build
```

The authoring script opens a new scratch project, exports every master, removes its tracks and leaves the empty project open. This avoids a local Audacity 3.7.7 last-window shutdown crash observed after all 22 exports had succeeded. No open user project is closed. Runtime files are self-contained and require neither Audacity nor source downloads.

See [validation](../../validation/voxel-battle/weapon-audio-20261015/README.md) for import, signal, mixer and packaged-resource results. Final headset listening/loudness tuning remains a separate hardware check.
