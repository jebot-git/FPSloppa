CQ models use the OpenGameArt assets and author credits listed in [sources.json](sources.json), with pinned SHA-256 hashes. The original weapon silhouettes, pistol magazines/wells and carbine clip are retained. The scout model includes the source scope, stock and silencer. The designator's forward direction is corrected. The launcher has a side-loading three-charge pack; other tools include the cordless drill, sci-fi grenade and the two linked supply cases.

Every exported model has fewer than 1,000 triangles, one material and one 512×512 diffuse atlas. The launcher also uses a 12-triangle pack sharing its atlas at runtime. The editable finish master was painted through Krita MCP and is retained as `finish_master.kra` alongside its PNG. Blender 4.5.9 LTS evaluates source modifiers, reduces geometry, unwraps UVs and bakes the finish onto the reduced meshes. The generated injector uses the same finish.

OpenGameArt lists all selected sources as CC0. The two Yughues/Nobiax case archives contain older CC BY-SA 3.0 notices; these notices are preserved in `deathmatch/weapons/cq`. To honor those notices, distribute the derived ammo/medical case assets with attribution to Yughues/Nobiax under [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). Original finish artwork and injector geometry are CC0. Source game sounds are separate from these model licenses.

Rebuild from the repository root:

```sh
python3 tools/cq_assets/fetch.py
blender -b --factory-startup --python tools/cq_assets/build.py -- test-results/weapon-sources deathmatch/weapons/cq
```

Krita GUI `/usr/bin/krita` with the Krita MCP addon was used for painting. Blender MCP was unavailable in this session, so Blender's batch Python API performed the bakes. Runtime gallery/effect checks use Vulkan Forward+ in `preview.gd` and `preview_fx.gd`.
