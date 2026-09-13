# Optional/community map packaging

Build from a full FPSloppa Git checkout with the maintained optional assets present:

```sh
python3 tools/package_optional_release.py
python3 tools/optional_maps/verify.py
```

Output: `dist/FPSloppa-<VERSION>-Optional-Community-Maps.zip` and its SHA-256 sidecar.
The archive has 53 maps in seven independently installable categories. See
[player instructions](PACK-README.md) and [sorted catalog](CATALOG.md).
`tools/prepare_release.py` includes this artifact in its explicit release allowlist.
Building the pack does not publish it or install it into base distributions.

The builder reads Arena Collection 1 directly from pinned release commit
`cec9edddcec7ccb2c8ab5541d96397e90fc6ce06` using `git archive`; it never checks out
old files over the working tree. A shallow/source-ZIP checkout needs that Git
object before rebuilding. Other inputs are the maintained `optional-map-pack/`,
relocated `optional-librequake/maps/` and `optional-community/maps/`.
All optional TF and Tiny Assault maps are excluded.
The catalog's original eight LibreQuake and five community entries must retain
their existing expansion tags. BSP hashes must match their provenance manifests.

`python3 tools/optional_maps/package.py --sync-catalog` registers missing optional
map metadata in `deathmatch/maps/manifest.json`. It does not install any map files,
add maps to default rotations, or alter existing catalog entries. Ordinary builds
require matching optional catalog metadata. New runtime builds filter restored
maps by their declared modes; older builds discover uncatalogued BSPs as imports.

Archive paths and file types are selected explicitly. Original converted AD/TF/
ThreeWave BSPs, unreviewed sources, graphical scene caches and old navigation
caches cannot enter through directory-wide copies. Original notices, current
texture receipts and historical validation reports travel with each category.
Historical reports describe their original test versions and source locations.
The new installer never executes a bundled scene or alters server/maplist settings.

Verification extracts the actual archive into a temporary directory, checks every
payload hash, tests dry-run/repeat/selective/conflicting/corrupt installations and
path escapes, then imports each installed BSP with the production catalog,
loader and runtime in a separate headless Godot process (at most two at once).
It checks mode filtering, geometry, collision, spawns and native CTF metadata.
Results are recorded in `docs/validation/optional-map-pack.json`; detailed logs
are in `test-results/optional-map-pack/`. This does not repeat historical bot-route
coverage or certify human balance/headset performance.
