# Map texture source audit — 12 September 2026

No ready-to-use companion normal, bump/height, specular, roughness, metallic or texture AO maps were found in the downloaded source packs used by the map artwork. Their surface relief and metallic highlights are represented in the colour pixels. This is a source-asset finding, separate from renderer capability.

| Inspected archive | Texture records | Other contents |
| --- | ---: | --- |
| Makkon Metal | 463 | Three example screenshots |
| Makkon Industrial | 1,632 | Screenshots, skybox, example MAP/BSP/LIT |
| Makkon Gothic Stone, used by Vesper Abbey | 2,089 | Trim tutorials, screenshots, skybox, example MAP/BSP/LIT, text documentation |
| Makkon CTF, also present locally | 32 | Licence |
| LibreQuake v0.09-beta development archive | 1,946 | Map sources and documentation |

All **6,162 records in 18 WADs** were parsed. Each is an uncompressed WAD2 mip texture containing exactly its header and four levels of indexed colour pixels, with no additional channel payload. Archive hashes match the versions recorded by the project. The [audit receipt](validation/map-texture-sources.json) retains archive file inventories, hashes, WAD counts and structural checks.

The packs do contain fullbright palette pixels, which FPSloppa extracts for glow. Skybox TGA files are environment colour images; example `.lit` files contain map lighting. Neither is an overlooked surface normal/specular map. The project's generated gothic relief atlas and its palette-conversion tools likewise supply colour artwork only. The baked AO added to the distribution is map lighting data produced by the light compiler, not a texture channel supplied by these artists.

The [LibreQuake source tree](https://github.com/lavenderdotpet/LibreQuake/tree/615969bd63ea6360b6ad35998ce14074b05b701b/texture-wads) was also checked for companion channel names. One apparent candidate, [`med_rock3_bump.png`](https://github.com/lavenderdotpet/LibreQuake/blob/615969bd63ea6360b6ad35998ce14074b05b701b/texture-wads/lq_terra/med_rock3_bump.png), is a coloured rock texture with shaded relief on visual inspection, and occurs as an ordinary colour texture in the release WAD. It is not a separate height or tangent-space normal map. Its nearby `med_rock3tilefix.xcf` authoring file contains two layers named `Pasted Layer` and `Background`. Other layered authoring files were not exhaustively inspected.

Makkon archive provenance points to [the author's Slipseer resource](https://www.slipseer.com/resources/makkon-textures.28/); this audit examined the actual local ZIPs, including Gothic Stone, rather than relying on the unavailable web page. The conclusion is limited to the supplied versions and does not claim that the authors never created other material assets.

There is no supplied PBR set here to recover by reconnecting importer slots. Adding these effects would require companion assets to be authored or sourced, along with map material support. No game materials, shaders or distribution bundles were changed for this source audit.
