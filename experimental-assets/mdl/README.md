# Standard VRM → MDL experiment

All 11 avatars listed in main's `deathmatch/avatars/models/manifest.json` at commit `bb5d0b19939ab807186bbb61ca2f1618c0621fe1` are converted. Each source SHA-256 matches the bundled manifest; titles, authors and source hashes are preserved in the JSON sidecars. Originals are unchanged.

The format is **Quake IDPO v6 MDL**, matching the project's existing MDLAvatarConverter reader, rather than GoldSrc/Source MDL. These are standalone experimental assets; FPSloppa's avatar selector still loads VRM.

Each avatar is normalized to 1.70 m (56 Quake units), collapsed to low polygon geometry with UV seams preserved, and flattened to a single 256×256 indexed skin. Clothing and hair colors are baked from the source glTF textures and factors. Transparency is flattened and MToon shading/outline effects are discarded. Small face, hair and hand details may be lost at this budget.

There is no runtime skeleton, full-body tracking, face tracking, eye tracking, finger tracking, morph system or spring simulation. The source skeleton is used offline solely to bake coarse movement into vertex frames. Faces and fingers remain fixed. The preview interpolates frames on the GPU using one surface per avatar, with no CPU pose updates or AI. This is not a measured VR performance comparison.

## Animation layout

| Clip | Start | Frames | FPS | Loop |
| --- | ---: | ---: | ---: | --- |
| idle | 0 | 6 | 6 | yes |
| walk | 6 | 8 | 10 | yes |
| run | 14 | 8 | 14 | yes |
| attack | 22 | 6 | 12 | no |
| pain | 28 | 4 | 12 | no |
| death | 32 | 8 | 10 | no |

Forty frames per model. These generic clips do **not** follow vanilla Quake `player.qc` frame ordering and need an animation mapping in a consuming application. Attack is a torso recoil gesture; no weapon is bundled.

## Palette and compatibility

Use the included shared `palette.lmp` (768 bytes), or the accompanying `*-skin.png` previews. MDL stores color indices, not a palette. Indices 224–255 are reserved and unused to avoid Quake fullbright colors. Stock Quake's palette requires a skin remap; copying these into a stock Quake installation directly will change their colors. Engine-specific player replacement behavior has not been tested.

## Results

| Model | Export vertices | Triangles | MDL bytes |
| --- | ---: | ---: | ---: |
| base_female.mdl | 906 | 671 | 233,312 |
| base_male.mdl | 1021 | 894 | 256,660 |
| hairsample_female.mdl | 855 | 503 | 221,852 |
| hairsample_male.mdl | 1018 | 672 | 252,592 |
| sakurada_fumiriya.mdl | 907 | 503 | 230,796 |
| sample_d.mdl | 999 | 671 | 249,308 |
| sample_d_darkness.mdl | 882 | 672 | 229,200 |
| sample_e.mdl | 978 | 672 | 245,712 |
| sample_f.mdl | 968 | 672 | 243,992 |
| sample_g.mdl | 967 | 672 | 243,820 |
| sendagaya_shino.mdl | 1010 | 672 | 251,216 |

Combined MDL size: **2,658,460 bytes**, versus **190,954,292 bytes** of source VRMs (98.6% smaller; this is asset storage, not a frame-time measurement). The largest exported model has 1,021 UV-split vertices, below the classic 1,024-vertex budget. All 440 frames decode through the existing Quake MDL reader; `validation.json` records the result. Maximum vertex quantization error is below 4.9 mm.

Rendered checks: `gallery-idle.png`, `gallery-walk.png`, `gallery-run.png`, `gallery-death.png`. Source licensing is CC0; see `LICENSE.txt`.

The reproducible tools are in `tools/vrm_to_mdl/`. Generated package: `standard-vrm-mdl-experiment.zip`.
