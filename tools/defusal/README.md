# DE asset workshop

`defusal_props.blend` preserves the Blender-authored objective props.
`build_assets.py` replaces only objects prefixed `DE_` in **DE Asset Workshop**;
other scenes are retained. Run in Blender 5.2 with:

```python
namespace = {"__name__": "asset_workshop", "__file__": "/path/to/FPSloppa/tools/defusal/build_assets.py"}
exec(compile(open(namespace["__file__"]).read(), namespace["__file__"], "exec"), namespace)
namespace["build"]()
namespace["export_assets"]()
```

The code reads live Blender enum values. Shader materials are located by node
type. Export uses the active scene and selected prop, preserving metre scale and
Godot +Y up. Key centers, back mount offset and cutter tip must stay aligned with
`deathmatch/counterstrike/bomb_interaction.gd` and `surface_mount()`.

`tools/defusal_preview.gd` renders the actual imported props, shop, floor/wall
placements and chest-mounted carrier. Source data here is excluded from Godot
import; only the GLBs in `deathmatch/pickups/defusal/` are runtime resources.

## Live six-round map series

```sh
python3 tools/defusal/run_series.py --output recordings/de-map-series-new
python3 tools/defusal/finalize_series.py recordings/de-map-series-new --require-all
```

This runs all five maps in `maps/de_maplist.txt` sequentially. Each local
dedicated server has twelve autonomous bots and one native Vulkan spectator
client. Sessions run in real time, six rounds each, switching roles after round
three. `series_rules.gd` changes only this test's match length and halftime;
combat, bot decisions, purchases, grenades and objective outcomes use production
code. Default DE match rules remain first-to-16.

The visible client follows living players, bomb carriers and defusers. A direct
RGB stream records only the game viewport at 1280×720/30 fps. Audio comes only
from that client's Master bus, including the current DE music; no desktop or
system audio is captured. The mux step aligns measured audio/video durations
without changing pitch. The FPSdemo and receipts retain the full 6v6 roster,
round results, half switch, utility and playback validation.

Each map folder contains `match.mp4`, `match.fpsdemo`, `match.json`,
`validation.json`, `view.json`, video stream metadata and logs. The destination
must be new. Use `--maps de_nuke_rebuilt` to limit a run, or `--smoke-seconds 8`
for a short recording-pipeline check; smoke captures are marked incomplete.
Finalization decodes every video and audio stream, checks the completed match
receipts against the current maps, and generates an `index.html` watch page.
