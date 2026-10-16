# UT99 anime avatar bundles

Thirteen selectable UTAV avatars: four Motoko faces, five AsiaBots colours, two AsiaBots2 variants, Kusanagi on Rumiko, and Team Anime / Asuka. Team identification remains game presentation; these are selectable skin variants, not automatic team palettes.

Source package URLs, archive SHA1, converted SHA256, size, topology and credits are recorded per entry in [the manifest](../manifest.json). Original readmes are retained in [credits](credits). AsiaBots2 is the additional green/black skin set present in the same FCommandoAsia package; its separate edits have no additional credited author. Kusanagi's skin author is uncredited; Rumiko is Roger [666] Bacon's model. Motoko is credited to Bongo / Bongoloid; AsiaBots to Asia Carrera, with the original Epic Games / Digital Extremes Female Commando geometry and animation retained. Asuka is Gotham & UDS's model based on Tom Woof's Manga Babes.

## Conversion

`tools/ut99_avatar/bundle_anime.py` consumes UE Viewer exports; run with `uv run --with numpy --with pillow python tools/ut99_avatar/bundle_anime.py --exports EXPORT_DIRECTORY`. The expected export layout is documented by its package paths. Stock texture skins reuse existing full animation/IK data. Rumiko has 683 vertices, 698 triangles and 498 frames; its malformed aggregate All alias is corrected from 499 to 498. Individual clip bounds remain checked.

Asuka needs Advanced Model Support in UT99: its skeletal package references `EpicUTPS2FemaleAnimation`. The offline PSK/PSA baker maps tracks by bone name, uses the PSK hierarchy and bakes 1,152 frames onto 618 vertices / 1,181 triangles. Original skeletal weights supply arm/head IK regions. No UnrealScript, AMS runtime or skeletal interpreter is shipped. JumpLgFr/JumpSmFr receive the aliases expected by the game. Existing native avatar animation, LOD and nearby tracked IK render all variants.

Dependencies: Rumiko archive SHA1 `9fae894e24141f5d59cb08d2c835fd09ad045331`; UT PS2 Characters archive `c5855c561137b405c50b80e116ff3c766d4dd7b0`; AdvancedModelSupport.u `f912e04b6d4bd97269530f2a25ce374e02430364`. Export helper: UTAvatarConverter v0.1.0 Linux portable (SHA256 `89b96f4ceea02732cb2c222edaab5503c93e9d88b9c04209a053b58ba9e348c6`), pinned UE Viewer revision `a0bfb468d42be831b126632fd8a0ae6b3614f981`. Helpers and original packages remain offline and are not game dependencies.

## Source terms

Original author terms apply; these conversions are not CC0 or newly relicensed assets. AMS's supplied readme restricts distribution of the mod to its unmodified complete archive and refers incorporation of parts to its source/SDK terms. The local Asuka animation bake is a technical prototype; this conversion does not establish permission to redistribute those animations outside UT. Preserve the original credits and resolve distribution terms before packaging it for public release.

[Validation and renders](../../../../docs/validation/anime-native-state-20261016/README.md).
