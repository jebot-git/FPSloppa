# Bundled Varq CS 1.6 DE conversions

Downloads and attempts conversion of all 30 entries on the supplied
[Varq DE listing](https://varq.net/cz/maps/counter-strike-1.6?option=1-2-3-4-42).
This is the supplied listing snapshot, not a crawl of the site's entire catalog.

18 maps passed runtime validation and are installed locally in `maps/` with
`de_varq_*` IDs. The embedded DE objectives make them available in DE hosting
and voting automatically. These maps now ship in the base bundle and join the
DE rotation alongside the existing rebuilt maps. `maps/varq_de_maplist.txt` lists
the converted subset.

## Reproduce

Requires Python 3.10+, libarchive (system library), the Python package below,
and the matching project's Godot executable. Original downloads and conversions
are local ignored artifacts; no third-party archives are committed or published.

```sh
python -m pip install -r tools/varq_de/requirements.txt
python tools/varq_de/import.py --godot /path/to/godot
```

`--fetch-only` downloads/extracts only; `--map de_mirage` selects one entry.
Archives are read as data. Only regular BSP, WAD and text files are extracted,
with bounded sizes and controlled destination names. Nothing from an archive is
executed. Separate text notices with identical basenames remain separate files.
The fetcher preserves existing downloads and refuses conflicting installed maps.

`sources.json` records source pages, download URLs, archive/file sizes and SHA256.
`results.json` records conversion status, missing-texture substitutes, warnings,
objectives and installed paths. Each map's full conversion/validation logs and
asset provenance remain under `local/MAP/`. Runtime match results and screenshots
are under `test-results/varq-de/`.

## Compatibility

The converter preserves compiled geometry, source UVs, embedded/supplied texture
art and RGB lightmaps. Missing WAD textures use explicitly reported procedural
substitutes. Source bomb volumes and team spawns become native DE objectives.
Sliding doors use the existing converter's native adaptation; unsupported
breakables/rotating doors become static cover. External models, sprites, original
skyboxes and unsupported scripts are omitted. These are adaptations, not complete
GoldSrc emulation. A/B naming follows entity order and has not been checked
against every painted site label.

Seven small/novelty maps have only one bomb site and were not reinterpreted as
two-site maps: `de_dust2_2x2`, `de_dust2_long`, `de_aztec2x2`, `de_rats`,
`de_nuke2x2`, `de_office_rats`, `de_nuke2x2_snow`.
`de_dust4ever` has four separate target groups and `de_dustlong_winter` has three;
these need explicit site assignments. `de_romans` uses point targets requiring
explicit planting bounds. `de_kabul_32` references an absent texture record, and
`de_inferno2se` has a spawn with no supporting floor within the converter's
128-unit search range. These 12 maps remain downloaded but uninstalled.

The converter was extended to accept unused negative texture-table slots while
still rejecting missing face-referenced records, and to tolerate conflicting
editor-only `mapversion` values while retaining strict gameplay-key validation.
The fixture suite contains regression coverage for both cases.

## Validation

Every installed map passes standing/floor checks at all spawns and sites,
lightmap/mipmap validation, and navigation paths from every spawn to both sites.
`acceptance.gd` additionally starts a real DE practice match on each installed map
and checks map selection, CS loadout, purchasing, arming, planting and defusing at
both sites. An empty-client ENet test on Mirage verifies automatic map transfer,
hash agreement and DE objective registration. Rendered previews use Vulkan.

```sh
./run.sh --headless --xr-mode off --script tools/varq_de/acceptance.gd -- de_varq_mirage
GODOT_BIN=/path/to/godot python tools/cs16_map_converter/run_network.py maps/de_varq_mirage.bsp --output test-results/varq-de/network
./run.sh --xr-mode off --rendering-method mobile --script tools/cs16_map_converter/preview.gd -- maps/de_varq_mirage.bsp test-results/varq-de/de_varq_mirage/preview
```

Original map and texture rights remain with their authors. Downloaded text
notices are retained under each source's `notices/` directory; conversion does
not relicense their content. The base bundle includes converted outputs and original notices; source archives
and the 12 rejected maps remain excluded. No remote deployment was performed.

Final run: all 30 archives downloaded; 18 installed and 12 withheld. The
installed set passes 4920 importer checks and 234 match checks. The converter
fixture suite passes 26 tests. The subsequent recovered-texture pass removes all procedural texture
substitutes from the installed set. Exact counts and
per-map results are in [results.json](results.json).

## Recovered texture pass

`retexture.py` replaces the generated slots in Dust2, Westwood, Abaddon,
Perfect Inferno and Dust2 Snow using indexed art from the already downloaded
DE BSP/WAD collection. Exact names take priority; `texture_aliases.json` lists
explicit material substitutes for absent artwork. Aliases are adaptations,
not claims that the donor image is the original missing texture. Masked texture
semantics, compiled dimensions and UV scale are preserved by the converter.
Original embedded art and supplied WAD entries remain authoritative.

```sh
python3 tools/varq_de/retexture.py --godot /path/to/godot
```

The tool validates candidates before installing, retains a local `before.bsp`,
asserts every nontexture BSP lump and native DE objective layout is unchanged,
and records individual donor archive paths/hashes in `texture_validation.json`.
All five maps now have zero generated texture slots. Donor authors retain their
rights; their original downloaded notices remain under `local/`. The `retextured/`
reports supersede the original `converted/` texture reports. The generic import
command intentionally refuses to overwrite these updated installed maps.

## Base selection update

Four validated Dust2 variants (Xmas, 2006, 2009 and Snow) were retired at user
request. The current base selection contains 14 Varq maps, plus the retained
Aztec and Train rebuilds; legacy Nuke, Inferno and Dust2 are also removed.
Earlier 18-map validation and texture-recovery receipts are historical evidence.
