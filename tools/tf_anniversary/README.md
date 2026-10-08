# TF 30th Anniversary archive conversion attempt

Requested source: https://gamebanana.com/mods/712767, uploaded by
Kalashnikov1947 as **Team Fortress 30th Anniversary Maps Archive** for
Team Fortress 2 Classified. The 126,555,459-byte ZIP was downloaded from
https://gamebanana.com/dl/1804759 and its published MD5 matched. The SHA256,
map hashes and inspected contents are recorded in `inspection.json`.

All four BSPs were extracted locally and tested with the actual map loader.
None is installed or added to the TF map list. `import_attempt.json` contains
its exact rejection diagnostics. Two exceed the current 25 MB import limit;
all four use compressed **Source VBSP version 20**, rather than the supported
Quake BSP29/BSP2 formats. Renaming or decompressing these lumps cannot convert
their brush collision, displacement surfaces, lightmaps or material system.

| Map | Source gameplay | Additional conversion requirements |
| --- | --- | --- |
| `4tdm_gasworks` | Four-team deathmatch | Dynamic team spawns; 90 displacement records |
| `dom_canalzon` | Canal Zone domination | Eight flag goals, eight control points and capture regions |
| `ff_dustbowl` | Staged flag assault | Three flag goals, stages and scripted spawn/round progression |
| `rctf_epicenter` | Reverse CTF | Reverse flag delivery and capture-zone ownership |

The closest first candidate is Epicenter, but its objective semantics still
need an explicit adaptation. Current native TF rules are not a replacement for
these Source scripts. Material dependencies absent from each embedded pak are
listed in the receipt: 3, 5, 122 and 4 VMT names respectively. Most custom art is
embedded; the missing base-game dependencies and external model resources must
also be resolved by a dedicated Source converter. No original scripts or
executables were run, and none of the source assets was redistributed.

`probe.py` decodes bounded Valve LZMA lumps, inventories entities and embedded
pak material names, and records the conversion blockers. To reproduce after
placing the verified ZIP and its four BSPs in ignored `local/`:

```sh
python3 tools/tf_anniversary/probe.py
./run.sh --headless --xr-mode off --script tools/tf_anniversary/attempt.gd
```

This is a documented unsuccessful conversion attempt, not a claim that the
four maps are playable. A Source geometry/material importer and explicit
objective translations are outstanding.
