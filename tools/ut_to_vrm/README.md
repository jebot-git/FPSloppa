# UT99 Asia Carrera skin → experimental VRM

The follow-up [standalone UT Avatar Converter](../ut_avatar_converter/README.md) now handles model/skin imports on Linux and Windows. Stock Female Soldier + original AsiaLatex/AsiaLatex2 and Female Commando + AsiaBots also passed conversion and FPSloppa tests; see [the new validation report](../../docs/validation/ut-avatar-converter.json).

Three **experimental VRM 1.0 avatars** were produced on 2026-09-12:

- `vrm/AsiaCarrera-Rumiko-purple-experimental.vrm` — 349,844 bytes
- `vrm/AsiaCarrera-Rumiko-black-experimental.vrm` — 328,988 bytes
- `vrm/AsiaCarrera-Rumiko-fur-experimental.vrm` — 327,424 bytes

All three pass the FPSloppa avatar-converter file checks and the game's
`deathmatch/tests/converter_avatars.gd` import test (3 tested, 0 failures).
The import test checks skeleton normalization, finite bone transforms, walk
animation availability and IK setup. It reports 20 runtime bones: the 19
mapped bones plus the importer root. The test emits one ObjectDB leak warning
at shutdown; it is retained in the log. No headset/live multiplayer test was run.

These prototypes have newly estimated skin weights. Shoulder, elbow, hip and
knee deformation needs manual review and refinement before treating them as
finished avatars. The block hands have no finger rig. There are no facial
morphs, blink/lip-sync expressions, eye bones or secondary hair physics.

## Sources acquired

All downloads are stored in `test-results/ut-to-vrm/sources/`; extracted data,
original readmes and screenshots are under `test-results/ut-to-vrm/unpacked/`.
The seven downloaded asset archives match their Unreal Archive SHA-1 values;
three key packages extracted from UMOD also match the archive's individual
package hashes. Full source URLs, credits, sizes and hashes are in
[`sources.json`](sources.json).

| Archive | Contents / conversion status |
| --- | --- |
| [rumikoasia.zip](https://unrealarchive.org/unreal-tournament/skins/A/asiarumiko_e79555ae.html) | Original Asia Carrera Purple, Black and Fur skins; used for the three final prototypes. Included readme explicitly credits Asia Carrera. |
| [6Rumiko.umod.zip](https://unrealarchive.org/unreal-tournament/models/R/rumiko_9fae894e.html) | Matching Rumiko mesh, by Roger [666] Bacon. |
| [asia bots version2.zip](https://unrealarchive.org/unreal-tournament/skins/A/asiabots_ae709677.html) | Original AsiaBots/AsiaBots2 textures extracted; AsiaBots Black now tested with stock Female Commando in the standalone converter. |
| [asialatex.zip](https://unrealarchive.org/unreal-tournament/skins/S/smile_5b8d7b5b.html) | Original Smile/AsiaLatex now tested with stock Female Soldier. |
| [asialatexnew.zip](https://unrealarchive.org/unreal-tournament/skins/A/asialatex2_f8b7e790.html) | AsiaLatex2 now tested with stock Female Soldier; team textures are available for material selection. |
| [40471_rumikoskinsasia.zip](https://unrealarchive.org/unreal-tournament/skins/A/asiarumiko_ae5fb5d6.html) | Alternate Rumiko package with Purple/Tiger/Spots/Latex selections. Archive author is Unknown. Used for the initial experiment, superseded by the credited original package above. |
| [AsiaBots_2_Skin_Edits_Repack.zip](https://unrealarchive.org/unreal-tournament-2004/skins/A/asiabots-2-skins-repack_5edb1170.html) | Asia Carrera textures edited by XDigitalStyleX, including PS2 mesh variants. Despite the site's UT2004 category, the included readme describes default/PS2 UT models; do not assume it supplies a UT2004 skeleton. |

The skins are texture packages, not standalone humanoid avatars. Rumiko is a
UE1 **VertMesh**, not a SkeletalMesh. Its exported animation header contains
498 vertex frames, with no joints or skin weights. The mesh has 698 triangles
and 683 exported UV vertices. Our triangle-expanded glTF has 2,094 vertices.
Simply attaching VRM metadata does not create a usable rig: the unrigged GLB
was tested and rejected with `A skinned humanoid model is required.`

## Implemented conversion path

1. Download ZIPs and verify their hashes. Extract UMOD files as data using
   `unpack_umod.py`; no Unreal installer or bundled game script is executed.
2. Export `6Rmko.u` using [UE Viewer](https://github.com/gildor2/UEViewer) to
   `Rumiko_d.3d`, `Rumiko_a.3d` and a sequence-description `.uc`. Export the skin
   package to PNG. The old prebuilt Linux executable required unavailable
   `libpng12`, so a native executable was built from official source locally.
3. `prepare_rumiko.py` reads the documented UE Viewer `.3d` layout, selects
   frame 0, applies the original mesh's relative X/Y/Z scale, converts axes,
   assigns the original UV/material slots and embeds two textures in a GLB.
   Height is an explicit 1.7m assumption; it is not a measured real-person height.
4. `rig_rumiko.py` adds 19 humanoid bones using manually chosen anatomical
   landmarks. It estimates up to four normalized influences per vertex from
   distances to bone segments, transforms limbs into a T-pose and writes new
   inverse bind matrices. This rig is specific to frame-0 Rumiko at 1.7m.
5. The existing avatar converter detects all required bones without mapping
   errors and writes VRM 1.0 metadata. Textures retain their original resolution.
6. Validate the resulting files with the actual game's avatar importer.

The required skeleton hierarchy follows the
[VRM humanoid specification](https://github.com/vrm-c/vrm-specification/blob/master/specification/VRMC_vrm-1.0/humanoid.md).
The original UT vertex animations remain in the extracted `.3d`; they are not
retargeted into the VRM. FPSloppa supplies its own locomotion and tracking.

## Reproduce from the extracted data

Requires Python with NumPy, the existing Godot avatar converter and UE Viewer.
Run from the FPSloppa repository root. Choose a new output directory because
the tools reject existing output files.

```sh
python3 tools/ut_to_vrm/unpack_umod.py SOURCE.umod NEW_UNPACK_DIRECTORY

test-results/ut-to-vrm/unpacked/UEViewer/UEViewer-master/umodel -export -png -uc -out=test-results/ut-to-vrm/exported test-results/ut-to-vrm/unpacked/rumiko-model/System/6Rmko.u
test-results/ut-to-vrm/unpacked/UEViewer/UEViewer-master/umodel -export -png -out=test-results/ut-to-vrm/exported test-results/ut-to-vrm/unpacked/rumikoasia-original/Textures/Rumikoasia.utx

python3 tools/ut_to_vrm/build_prototypes.py test-results/ut-to-vrm/exported test-results/ut-to-vrm/rebuild
```

For native UE Viewer compilation, unzip the official source, restore executable
permissions on `Tools/genmake` and `Unreal/Shaders/make.pl`, and run `bash build.sh`.
The local source ZIP SHA-256 and generated executable hash are recorded in the
validation report. The `.3d` parser references `Exporters/Export3D.cpp` and
`Unreal/UnrealMesh/UnMesh2.h` from that source.

## Evidence and remaining work

- `test-results/ut-to-vrm/original-game-import.log`: all three final VRMs import.
- `test-results/ut-to-vrm/original-vrm-results.json`: converter checks and hashes.
- `test-results/ut-to-vrm/prepared/`: original/unrigged GLBs, rigged GLBs, VRMs and previews.
- `test-results/ut-to-vrm/prepared/AsiaCarrera-Rumiko-purple-posed.png`: CPU skinning preview with bent elbows/knee and turned head, evaluated from the final VRM's joints, weights and inverse bind matrices. This is a technical preview, not a headset screenshot.
- `docs/validation/ut-to-vrm.json`: acquisition and validation summary.

For a finished avatar, inspect and paint joint weights in a modeling tool,
adjust shoulder/wrist and knee landmarks as needed, then test crouching,
arm reach and head motion in VR. Hand detail and expressions would require
new mesh/shape work. For AsiaLatex and AsiaBots, acquire their exact matching
base meshes and devise separate landmarks; this Rumiko-specific rig cannot
be reused blindly.

Source notices are preserved with the downloads. AsiaLatex's readme credits
Husch's Domina1 contribution, restricts commercial use and requires its readme
when redistributing those skins. The original Rumiko skin/model readmes do
not establish a general license for this VRM conversion. The generated VRM's
restricted-use metadata is not a grant of source rights. Files are kept local
and are not added to the game's distributed avatar manifest or release packs.
