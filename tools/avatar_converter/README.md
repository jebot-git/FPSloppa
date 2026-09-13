# AvatarConverter

This tool now has its own [GitHub repository](https://github.com/jebot-git/AvatarConverter) and
[Linux/Windows v0.1.0 downloads](https://github.com/jebot-git/AvatarConverter/releases/tag/v0.1.0). Source, build instructions,
tests and licence notices are maintained there.

Extract the portable ZIP and run the executable. Export a `.vrm` to FPSloppa's
`vrm/` directory, then select it in the normal avatar picker.

To build locally, clone the independent repository (the directory is ignored by
FPSloppa's Git repository):

```sh
git clone https://github.com/jebot-git/AvatarConverter.git external-tools/AvatarConverter
python3 tools/build_avatar_converter.py
```

The build wrapper also accepts `--checkout /path/AvatarConverter`. Build outputs stay in
that checkout's `artifacts/` directory. See the independent README for build
prerequisites; the UT tool requires its source-built UE Viewer helpers.
