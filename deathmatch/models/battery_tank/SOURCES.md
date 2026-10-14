# Battery tank

Combined CC0 models:

- **atze**, [Tankcar](https://opengameart.org/content/tankcar). Retained archive `tools/battery_tank/source/panzerwagen.7z` includes original Blender source and CC0 license note. Original 1,266 triangles; retained hull/wheels without cannon, turret and antenna: 1,136 triangles.
- **mutantleg**, [Missile Launcher Tank](https://opengameart.org/content/missile-launcher-tank). Retained `launcher_tank.zip` includes `rockethead.obj` and its original skin; the battery has 136 triangles, including eight disconnected missile nose caps.

`tools/battery_tank/export_tank.py` combines the retained hull reduced to **817 triangles** with the **136-triangle** battery, totaling **953**. Vehicle length is **4.8 m** and wheel-to-wheel width **4.63 m**, with a separate `Aim` pivot at 1.8 m. Godot generates mesh LODs, and runtime uses the existing baked jungle material and shared range/frustum culling policy, no dynamic lights or shadows. The simple stationary/drive collider is authored separately.

The hull retains its original **512²** camouflage/tire/metal atlas and original UVs. Battery housing and hinge use a separate **256² crop of only the green camouflage area**, so no tire, rusty metal or black atlas regions can appear on the housing. Its **eight missile tips** retain the original **128² battery skin** and UVs; they are explicitly excluded from camouflage. Three opaque materials / three draws per tank. All textures use mipmaps and GPU compression. The GLB embeds textures and Godot extracts the adjacent PNGs.

Rebuild from repository root:

```sh
blender -b --factory-startup --python tools/battery_tank/export_tank.py
godot --headless --xr-mode off --editor --path . --import
```

The exporter requires 7z and Blender's bundled numpy. Source archives are excluded from Godot import by `.gdignore`. `tools/battery_tank/mesh-budget.json` records the output budget and verifies exactly eight missile components.
