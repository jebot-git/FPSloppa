# MDL Avatar Converter — experimental

The Quake converter is maintained in its own
[MDLAvatarConverter repository](https://github.com/jebot-git/MDLAvatarConverter).
[Download experimental v0.1.0](https://github.com/jebot-git/MDLAvatarConverter/releases/tag/v0.1.0)
for Linux or Windows, extract the ZIP, and run the executable.

It supports Quake IDPO v6 MDL files and Quake PAK archives, with matching game
palettes, grouped skin/frame selection, editable rig landmarks and VRM export.
GoldSrc and Source MDL are unsupported. Rigging remains experimental; inspect
arm and attached-equipment deformation before using an avatar.

Export a VRM into FPSloppa's `vrm/` directory and use the normal avatar picker.
To build locally:

```sh
git clone https://github.com/jebot-git/MDLAvatarConverter.git external-tools/MDLAvatarConverter
python3 tools/build_mdl_avatar_converter.py
```

The wrapper also accepts `--checkout /path/MDLAvatarConverter`; outputs stay in
that checkout's `artifacts/` directory. See its README for Godot build prerequisites.
`python3 tools/test_mdl_avatar_converter.py --ui` runs the synthetic source/UI
suite using an installed Godot editor. Portable binaries need no Godot or Python.
