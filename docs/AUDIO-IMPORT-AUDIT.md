# Music level and BSP lighting audit

Music now has a −12 dB trim on ArenaMusic, applied in the audio preferences path so it survives track changes and crossfades. The music buttons adjust in 1% increments. Existing saved percentages are preserved: 10% changes from −20 dB to −32 dB; 1% produces −52 dB, and zero still mutes. This reduces signal amplitude to about one quarter of its previous value at the same percentage. Other audio buses retain their existing gains.

The music regression passed 54 assertions, including actual bus levels, mute/unmute, crossfade persistence, track selection and looping. The presentation regression passed 29 assertions, including the real music button's one-percent adjustment and saved setting. The simulated VR UI regression also passed 57 assertions, including controller-pointer adjustment of the music setting. These are mixer/control checks using Godot's Dummy driver, not a calibrated loudspeaker loudness measurement.

## Import findings

The BSP importer **does not generate a light bake or ambient occlusion**. It applies existing light samples only when the worldspawn contains `_fpsloppa_bake` set to `1`. In that path, embedded BSPX `RGBLIGHTING` supplies colour; otherwise the native lighting lump supplies grayscale. The optional `LMSHIFT` data controls supported luxel spacing. This path does not load external `.lit` sidecars.

AO is already merged into the light samples of the prepared distribution maps. It reaches the rendered surface through the baked-light texture and UV2 coordinates, rather than a separate AO texture or a runtime SSAO pass. The importer’s occlusion-culling option is a visibility optimization and does not create AO. The ordinary import path does not invoke ericw-tools, Godot LightmapGI or any AO bake process.

An unmarked downloaded BSP keeps legacy materials even if its file contains a native lightmap. This is an existing opt-in limitation, not evidence that arbitrary imports receive the distribution's lighting treatment. Importer behavior was audited, without globally changing third-party lighting policy or rebaking downloaded maps.

## Verified cases

| Fresh import | Applied baked faces | Colour | Cache reload |
| --- | ---: | --- | --- |
| Current Ashfall | 33,505 | RGB | Identical atlas pixels/materials |
| Original external Softbox | 0 | Legacy path | Identical materials |
| Softbox diagnostic opt-in copy | 2,699 | Grayscale | Identical atlas pixels/materials |
| Pressureworks AO-off control | 6,350 | RGB | Identical atlas pixels/materials |
| Pressureworks AO-low bake | 6,350 | RGB | Identical atlas pixels/materials |

All five cases had zero invalid or overflowing baked faces. AO-off and AO-low retain different atlas hashes after import and serialization, proving that the pre-baked difference survives. All source BSP hashes remained unchanged. The existing luxel/UV/gutter/fallback regression also passed.

The AO pair is retained from the prior controlled bake, whose only intended lighting difference was baked dirt/AO. That experiment's [method and limitations](../tools/lighting_experiment/AO.md) remain applicable. In particular, the earlier attempt to rebake the external BSP changed light-style assignments and was rejected; import-time rebaking is not an interchangeable substitute for reading its existing lightmap.

[Audio test receipt](../test-results/music-volume/results.json) · [BSP audit receipt](../test-results/bsp-import-audit/results.json) · [Audit script](../tools/lighting_experiment/import_audit.gd)
