# Native Tribes 2 vehicle adaptations

`models.gd` builds Wildcat, Shrike, Havoc, Beowulf, Thundersword and Jericho with the existing ST hull atlas:
bronze armor, gunmetal trim, recessed vents, neutral team panels and blue engine
emission. Dominant-axis projection maps each convex face into one atlas tile;
all triangles of a face share that projection. Textures are embedded with mipmaps
and use anisotropic filtering. Material naming preserves runtime team coloring.

```sh
./run.sh --headless --xr-mode off --script tools/t2_vehicles/models.gd
./run.sh --xr-mode off --audio-driver Dummy --rendering-method mobile --script tools/t2_vehicles/preview.gd
python3 tools/t2_vehicles/package.py # requires Pillow
```

The preview script checks material surfaces, UV bounds and mipmaps before
capturing front, rear, side, top, cockpit and blue-team views in a 1600×1000
offscreen viewport. Packaging verifies model hashes against the preview audit
and produces `test-results/t2-vehicles/textured/index.html`, `vehicles.jpg` and
the tracked `validation.json` receipt. Regenerate previews after rebuilding
models so the receipt refers to the exact current native assets.
