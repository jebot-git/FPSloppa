# SloP application icon

Generated with the built-in image generation tool on 2026-09-11 using
`slop-title-parody.png` as the visual reference. It retains the blue/gold SloP
lettering and white-haired VRM heroine, simplifying the scene for small sizes.
The character reference derives from the bundled CC0 VRoid sample F; see
`vrm/README.txt` and `slop-title-parody.md` for the title artwork's provenance.

The unmodified 1254×1254 output is `slop-icon-source.png`. The installed asset is
`deathmatch/icon-final.png`, downsampled with Lanczos to 512×512 RGB. It was also
visually checked at 64×64. The project and Windows export already reference that
path. Android's unset launcher icon overrides fall back to the project icon, as
documented in the [Godot Android export reference](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformandroid.html).
No platform binaries were exported for this update. Source art stays excluded
from Godot exports through the existing `docs` exclusion and `.gdignore`.

## Final generation prompt

Create a finished square videogame application icon inspired by the supplied SloP title-screen artwork. Reference image is a style and brand reference, not an image to reproduce in full. Simplify to a bold readable emblem: large exact text 'SloP' in the same angular carved-metal blue-steel-to-molten-gold lettering, occupying the central upper two thirds. Beneath it a compact portrait of the reference's short white-haired teal-clad VRM heroine, with a fierce playful expression, framed by very simple orange fire and near-black volcanic shapes. Dark charcoal background, crisp bold silhouette, restrained number of large shapes, strong contrast. The lettering must stay completely legible, not hidden behind the portrait. Square composition with generous 10% safe margins for desktop and Android icon masking; all essential elements within the central 75%. No calendar, no extra characters, no small decorative text, no border mockup. Not a screenshot or a poster: one polished compact game icon, readable at 64 pixels. Output a square raster image.
