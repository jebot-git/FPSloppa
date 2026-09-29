# Armour asset candidates

Reviewed 2026-09-27.

## Blend Swap candidates

All four public listing pages and their preview images were inspected. All four
download pages require sign-in; no source `.blend` file was downloaded or
inspected. Counts and rig descriptions below are the authors' statements, not
measurements. No geometry or textures from these candidates are in the game.

| Candidate | Listed licence / source | Assessment for this project |
| --- | --- | --- |
| [Mech Kitbash](https://blendswap.com/blend/9655), masterxeon1001 | CC0; Blender 2.6x/Cycles; 3.17 MB. Author describes a simple control rig without IK. | **First choice for Heavy parts.** Angular chest, layered shoulder plates, forearms and shins suit the requested direction. Reduce the many small parts, shorten the long robot arms and replace claw hands with the avatar's hands. The peaked head and thin robotic waist should be replaced, preserving the player's head and a human torso underneath. |
| [Mech Man](https://blendswap.com/blend/23518), koumis | CC0; Blender 2.8x/Cycles; 24.2 MB. No rig or geometry budget documented. | **First choice for a Medium base.** Human proportions, a continuous torso, thigh shells and conventional feet require less reshaping. Rounded shoulder/limb shells need broader flat panels to match Tribes; remove the helmet and modelled hands. Its screenshot is a rendered scene, so file size does not establish the runtime mesh/texture cost. |
| [Nomad](https://blendswap.com/blend/3437), Mennoknight | CC0; Blender 2.5x/Blender Internal; 14 MB. Author reports about 300,000 viewport / 800,000 rendered vertices, revised rig and textures, and added minigun. | Useful **secondary parts reference**, especially forearm shells and mechanical joints. Rounded, skeletal proportions and split/clawed feet are a poor whole-body fit for angular Heavy. Needs a new low-poly mesh and baked details; the existing model is far beyond the current body budget. |
| [Nomad-Desert Mech](https://blendswap.com/blend/3377), Mennoknight | CC0; Blender 2.5x/Blender Internal; 1.75 MB. Author describes a rig, walk/run actions and unfinished work; comments report a texture-packing fix. | **Prefer the finished Nomad above.** This is its earlier version, with exposed waist/shins and more organic hands, not a distinct armour family. It adds little value as another full body. |

These suitability judgements are based on the public renders. Topology, actual
evaluated triangle counts, armature compatibility, packed images and separable
parts remain unverified until the source files are available. Saved public pages
and previews are in `test-results/tribes-arsenal/references/blendswap/`.

The listed [CC0 dedication](https://creativecommons.org/publicdomain/zero/1.0/)
allows copying, modification and redistribution, including commercial use,
without an attribution requirement. Keep author/source records nevertheless.
CC0 only covers rights the contributor can grant: the early Nomad explicitly
uses textures from morguefile.com without identifying the individual images.
The later Nomad derives from that asset. Replace their textures with the
project's own atlas, or verify the original image terms individually before
redistribution. Treat any packed photographs, logos and background images in
the other files separately too; none are needed for the armour conversion.

The intended conversion is to retain selected shell shapes, rebuild around the
existing humanoid proportions, and bind them to the game's 19-bone armour rig.
The donor's IK is not needed: the player's skeleton already drives the body.
Preserve head/neck and hand openings, remove donor heads and hands, add neutral
team-colour panels, and use the shared mipmapped atlas. Aim near the existing
8–9k triangles per body, with a small material count and no new spring bones.
Import old `.blend` files with automatic script execution disabled; check their
legacy materials/modifiers before baking and exporting headless VRM 0.0.
Validate head/hand retention, class silhouette, team colour and first-person
masking with the existing three-class avatar gallery tests.

**Decision:** shortlist Mech Kitbash for Heavy and Mech Man for Medium. Light
should retain a closer-fitting body; none of these complete robots is a good
direct Light replacement. Nomad is optional detail reference, not the primary
base. Actual adoption remains pending source-file access and mesh inspection.

## VRoid Hub candidates

- https://hub.vroid.com/en/users/76351406 — requested mechanical model creator.
  Live access requires CAPTCHA and the creator listing was unavailable through
  the search index. No models or model-specific terms could be inspected.
- https://hub.vroid.com/en/characters/3426129451528710705/models/854170553273452198
  — **Operator#214160_ArmoredCoreSuit**, Marquina. The indexed page reports VRM
  0.0, avatar use/violence/alteration/redistribution allowed, corporate and
  individual commercial use allowed, attribution required. The creator describes
  it as a mecha pilot model. Its accessible portrait suggests a slim pilot suit
  or undersuit candidate rather than a Heavy armour base. Download and full mesh
  inspection remain unavailable behind VRoid authentication/CAPTCHA. Do not
  infer terms for other models from this listing.

No geometry or textures from either of those two online candidates were copied
into the game. The later locally supplied KEIV source was adopted as described
below. When another model is
supplied, inspect its embedded terms, humanoid weights, material count, polygon
budget, hand/head separability and modification/redistribution terms before
integrating it, and retain the creator's attribution with derived assets.

The eight added historical VRoid avatars are a separate CC0 collection, with
source and license evidence recorded in `vrm/SOURCES.json`. They are usable
whole avatars as well as test subjects for body replacement; they are not
claimed as mechanical armour sources.

### Locally supplied KEIV suits

The user subsequently supplied six VRM 0.0 files in Downloads. All six were
imported into Blender 5.2 with VRM Add-on 4.7.2, their geometry and embedded
terms inspected, and a full-body comparison rendered. The five named files
credit **KEIV**. Their embedded VRoid Hub licence URLs permit modification,
redistribution and violent expression, require credit, disallow corporate
commercial use and restrict personal commercial use to `nonprofit`. They are
**not CC0**. Retain these restrictions and the exact licence URL on derivatives.
The embedded terms are recorded verbatim in
`docs/validation/vroid-armour-candidates-2026-09-27.json`.

| Downloads filename | Embedded title | Whole / body triangles | Body materials | Suit assessment |
| --- | --- | ---: | ---: | --- |
| `4746773052303664305.vrm` | MEC-VAL-白狐 | 44,651 / 15,237 | 7 | **Preferred Light / undersuit donor.** Lowest body cost among the eligible models, enclosed torso and limbs, useful chest and boot forms. Remove redundant pouches/holster and reduce protruding plates for an undersuit. |
| `7136124279442785104.vrm` | MECHANICAL-VALKYRIE-F.L.1 | 45,189 / 15,997 | 10 | Alternate Light donor, with suitable boots and mechanical seams; more material consolidation needed. |
| `686393150552586347.vrm` | MECHANICAL-VALKYRIE-F.L.2 | 46,307 / 17,115 | 12 | More costly variant; its extra body surfaces offer little advantage when hidden beneath armour. |
| `7070848076468546799.vrm` | CLONE-VAL | 39,257 / 15,655 | 10 | Lowest whole-avatar count because of shorter hair. That saving does not help a headless donor whose original head/hair will be discarded. |
| `9015280639729005329.vrm` | MEC-VAL-F.L.1_ver.L.O.M | 45,189 / 15,997 | 10 | Similar body budget to F.L.1, with additional chest insignia; no compelling advantage for neutral team equipment. |
| `27048436064424208.vrm` | No title or author recorded | 46,305 / 17,113 | 6 | **Exclude from shooter use:** embedded metadata and licence URL explicitly disallow violent expression. Inspected only, not tested in gameplay. |

The five eligible files pass the production 25 MB/64-million-pixel limits.
Each was tested against all three existing armour classes: **15 combinations,
880 checks, no failures or script errors**. This verifies original head/hands,
face morphs, skin binding, team panels, first-person masking and restoration.
It tests the current project armour replacing these avatars, not a newly
converted KEIV armour body. The files remain outside the bundled avatar list.

They are close-fitting mechanical suits with long, slim limbs, not ready-made
Medium or Heavy shells. Body meshes contain 61–88 connected components in the
eligible set, allowing local extraction of some garments and attachments, but
material/skin seams also split components; component count is not a part count.
Full avatars carry 18–25 spring groups and 37–43 million embedded texture
pixels. A body conversion should discard donor face/hair/hand geometry, unused
images, facial blend shapes and spring chains; keep the player's original head
and hands. Rebind rigid plates and flexible joints to the existing armour rig.

The selected direction is:

- **Light:** simplify MEC-VAL-白狐 into a close suit with modest chest, forearm,
  knee and shin protection. Preserve wrist/neck openings and use separate,
  neutral team-colour regions. F.L.1 is the alternate.
- **Undersuit:** retain only visible waist, elbow, shoulder and knee flex areas
  beneath Medium/Heavy shells. Delete covered surfaces instead of rendering a
  complete 15k-triangle body underneath another body. Consolidate the needed
  textures into a mipmapped atlas; aim for 2–4 body materials and roughly
  8–10k visible triangles for a finished Light conversion.
- **Medium / Heavy:** build volume with external plates and purpose-built
  shoulders, thighs, greaves and backpack mounting. Heavy remains angular.
  Simply enlarging the suit does not provide the requested class silhouette.

The inspection scene remains in Blender as `VRoid Armour Inspection`.
`test-results/tribes-arsenal/vroid-inspection/candidates-front.png` compares all
six; per-candidate native armour galleries and JSON reports are alongside it.
This inspection preceded the coordinated-family implementation below.

## Further Medium and Heavy candidates

| Source | Verified status | Decision |
| --- | --- | --- |
| [Exotrooper](https://opengameart.org/content/exotrooper-low-poly), nublet | CC0. Source downloaded and appended in Blender without executing source scripts. Measured 908 triangles: separate 124-triangle head and 784-triangle body, with a 55-bone rig. Old file imports with no material slots or packed textures in Blender 5.2. | **Accessible base for a Medium blockout or simpler Heavy variant.** Broad chest, enclosed humanoid joints and large shins fit better than a bare robot. Needs substantial added geometry, new texturing, neck/wrist cuts, angular Heavy shoulders and retargeting. Not ready for final use at its existing detail level. |
| [Animated Mech Pack](https://quaternius.com/packs/animatedmech.html), Quaternius | Official page lists four animated, textured CC0 mechs; public preview inspected. Source not imported. | Optional donor for angular shin/forearm panels and mechanical joints. Non-human legs, mechanical claws and some head-in-torso forms make the complete bodies a poor fit for avatar replacement. |
| [Mechsuit](https://poly.pizza/m/cQFoSfuK7Tf), Pepper Media | Listing says Creative Commons Attribution; collection credits identify CC-BY 3.0. Public render inspected; source not imported. | Lower priority: useful angular forearm and chest plates, but narrow rod legs, gun-like forearms and missing human head opening require major rebuilding. |
| [Machine Man](https://poly.pizza/m/mWLnPxLY6X), Vaporworks | Listing says Creative Commons Attribution, FBX/glTF and animated. Public render inspected; exact licence version/source not yet inspected. | Reject as a complete armour base: its dangling human legs, very long mechanical legs and oversized arms are a piloted exoskeleton rather than wearable armour. |

Mech Man and Mech Kitbash from the Blend Swap shortlist remain the stronger
visual candidates for Medium and angular Heavy respectively, pending access to
their files. Exotrooper is the immediately inspectable CC0 fallback. Existing
project shell geometry can also be remodeled over a reduced suit without
introducing another donor rig or its performance costs.

## Adopted coordinated family

MEC-VAL-白狐 is now the common fitted suit beneath all three classes. Its
Onepiece body and one sleeve layer are extracted and rebound to the 19-bone
armour rig. Donor head, hands, hair, accessories, redundant garment layers and
spring physics are omitted. Light and Medium retain its fitted footwear; Heavy
removes covered calves and torso patches beneath the enclosing shells. Two
source textures are packed into one opaque atlas with mipmaps.

New plates develop the selected angular, humanoid direction with a shared
chevron chest, bevels, inset panels, class marks, hardware and finish. No
Blend Swap or Exotrooper mesh is copied: the unavailable Blend Swap files are
not a build dependency. The three bodies retain the same underlying proportions
and shared parts while varying coverage:

- Light: mostly visible suit, small breastplates/shoulder caps, bracers and
  strapped knee pads; no external thigh, shin or foot shells.
- Medium: the first iteration's Light shell, including chest, forearm, thigh
  and shin plates, with fitted suit footwear.
- Heavy: wider/deeper torso, lower broad angular shoulders, flank protection,
  enclosed thighs/greaves and reinforced boots. Shin plates stop above the
  ankle to improve crouched clearance.

Light/Medium add a flexible open neck gaiter and rim bound to the neck, covering
the head-swap seam while retaining the original head. The existing avatar hands,
facial morphs, team colours and first-person masking remain supported.

Budgets: Light 8,610; Medium 11,442; Heavy 9,814 triangles; four material
surfaces and no added spring groups per body. Shared textures are a 2048×1024
suit atlas and 1024×512 plate atlas. The authoring Blender file contains only
this family scene, with packed textures.

KEIV's exact source metadata is preserved in the generated VRMs and in the
distributed [sources manifest](../deathmatch/weapons/tribes/sources.json).
The combined bodies are not CC0; see the
[distributed attribution and licence](../deathmatch/weapons/tribes/SOURCES.md).
The source file itself remains authoring input, outside the selectable avatar
bundle. Final validation is recorded in
`docs/validation/tribes-armour-family-2026-09-27.json`.

### Heavy iteration 4

The next Heavy pass revisits the cached Mech Kitbash render and the original
Tribes manual's armour silhouettes, developing new geometry over the same
MEC-VAL suit. It replaces the scaled Medium-like shell with a deeper canted
cuirass, split shoulder bridge and overlapping upper-arm armour, wrapped
abdominal plates, broad pelvic chassis, femur-bound hip skirts, reinforced
forearm/thigh/greave shapes and treaded boots. Rear cooling louvres, calf
service covers and a pack coupling make the rear view deliberate as well.
The existing atlas, class badge, team panels and original avatar head/hands
keep it in the same family as Light/Medium. No additional donor asset is used.

Heavy falls from 11,828 to 9,814 triangles (17.0% fewer), retaining four surfaces,
19 bones and zero added spring groups. Light/Medium native resources and shared
texture resources are byte-identical to the previous iteration. The authoring
scene contains all three suits; `heavy_shell.py` builds the new Heavy geometry.

Close front/side/rear renders, crouching, and all five packs were reviewed. This
exposed and fixed the existing desktop VRM pack frame: imported model rotation
must be removed before applying the rearward pack offset. That attachment fix
is checked across the bundled-avatar matrix. See
`docs/validation/tribes-heavy-iteration-2026-09-27.json` for the current receipt.

## First-person culling follow-up — 29 September 2026

Replacement armour now registers with the avatar rig’s visibility and hand-mask
updates. Head, neck and torso triangles use the same cached first-person mask
as ordinary avatars; arms, original hands and legs remain visible. View switches
and first-person rebuilds apply immediately, fixing the previous one-update
delay. Unequipping unregisters the replacement cleanly; team colours and complete
third-person meshes are restored. Armour materials remain unchanged.

All three classes passed immediate-transition, rebuild, glove and unequip checks,
plus avatar/import/scaling regression and Vulkan inspection. Evidence is in
`test-results/st-armour-culling`; see the
[validation receipt](validation/st-armour-culling-2026-09-29.json).
