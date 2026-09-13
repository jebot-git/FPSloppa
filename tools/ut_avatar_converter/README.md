# UTAvatarConverter

This tool now has its own [GitHub repository](https://github.com/jebot-git/UTAvatarConverter) and
[Linux/Windows v0.1.0 downloads](https://github.com/jebot-git/UTAvatarConverter/releases/tag/v0.1.0). Source, build instructions,
tests and licence notices are maintained there.

Extract the portable ZIP and run the executable. Export a `.vrm` to FPSloppa's
`vrm/` directory, then select it in the normal avatar picker.

To build locally, clone the independent repository (the directory is ignored by
FPSloppa's Git repository):

```sh
git clone https://github.com/jebot-git/UTAvatarConverter.git external-tools/UTAvatarConverter
python3 tools/build_ut_avatar_converter.py
```

The build wrapper also accepts `--checkout /path/UTAvatarConverter`. Build outputs stay in
that checkout's `artifacts/` directory. See the independent README for build
prerequisites; the UT tool requires its source-built UE Viewer helpers.

Quake and Half-Life/GoldSrc prototypes and results are in
[MDL research](https://github.com/jebot-git/UTAvatarConverter/tree/main/research/mdl).
They are separate from the released UT99 interface.
