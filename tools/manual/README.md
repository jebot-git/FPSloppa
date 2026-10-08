# Player manual build

The deliverable lives in `docs/manual/index.html`. Open it directly in a browser;
no server, network, package installation or game launch is required to read it.
Keep `manual.css`, `manual.js` and `assets/` beside it. The PDF is linked from its
top bar, and both formats are linked in the project README.

## Rebuild

1. Edit the chapter content in `tools/manual/build.py` and the layout/interaction
   files `docs/manual/manual.css` and `docs/manual/manual.js`.
2. Run `python3 tools/manual/build.py`.
3. Install Playwright and its Chromium browser in your preferred environment.
4. Run `node tools/manual/render.mjs` to check the browser layout and export the
   PDF. `PLAYWRIGHT_MODULE` may point to an installed Playwright package;
   `CHROMIUM_BIN` may point to a compatible Chromium executable.
5. Inspect the desktop/mobile screenshots under `/tmp/fpsloppa-manual-qa`, then
   render all PDF pages with `pdftoppm` and inspect their page breaks and diagrams.
   `MANUAL_QA_DIR` overrides the temporary QA directory.

The renderer checks image decoding, internal anchors, unique IDs, chapter search,
controls filtering, mobile navigation, viewport overflow and JavaScript errors.
It exports tagged PDF with bookmarks, internal links and repository references.
It removes local-only image/source links from PDF so it has no machine-specific
file URLs. PDF content is generated from the same HTML as the browser edition.

## Illustration provenance

`docs/manual/assets/manifest.json` records the original repository path, caption
and output dimensions of every image. `tools/manual/prepare_assets.py` rebuilds
WebP assets using Pillow when the original ignored test captures are available.
The committed WebP assets are sufficient for normal HTML/PDF rebuilding.
Screenshots are existing native game captures or engine-rendered validation
fixtures, labelled accordingly. Diagrams are inline SVG authored in the builder.
No generated illustration is represented as a gameplay screenshot.

## Scope

Updated source edition, checked 8 October 2026 against revision `12a638c`.
Includes the desktop launcher/updater, player colours and clan tags, BSP/VRM
workflows, approved CC0 music and playlists, HK reload sequence, full expansion
map coverage, nine ST vehicle types and Scout/Shrike bot air support.
Current bindings/code and later feature notes supersede historical release prose.
The handbook covers 13 modes, including prototype Titanball. The game code is
unchanged. Headset comfort and multiplayer balance were not retested for this
manual.

Run `python3 tools/manual/package.py` after validation to create
`output/FPSloppa-Manual.zip` and the delivery copy under `output/pdf/`.
The portable ZIP drops source-tree-only links while preserving online references,
chapter links, all illustrations, CSS/JS and the hyperlinked PDF.
