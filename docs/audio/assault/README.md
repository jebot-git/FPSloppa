# Assault theme: Mega Destruction

“Mega Destruction” (`mega_destruction.xm`) by **Zilly Mike** is listed by Mod Archive as **Public Domain**, verified September 11, 2026.

- Module entry: https://modarchive.org/index.php?request=view_by_moduleid&query=50252
- Original download: https://api.modarchive.org/downloads.php?moduleid=50252
- License link supplied by the archive: https://creativecommons.org/licenses/publicdomain/

The original XM is preserved here. Runtime playback uses `deathmatch/audio/music/mega_destruction.ogg`, retaining the original instruments and arrangement. It is converted to 44.1 kHz stereo Vorbis, with a 45 Hz high-pass, 14 kHz low-pass, short edge fades and two-pass loudness mastering targeting −19 LUFS / −3 dBTP, matching the other gameplay tracks. Regenerate with `python3 tools/prepare_assault_theme.py` (FFmpeg with libopenmpt and libvorbis required). Source and output SHA-256 hashes are recorded in the adjacent runtime `.score.json` metadata.

AS selects this theme automatically, loops it and uses the existing music volume and 2.5-second crossfade. Lobby and title music retain priority when outside an active match. Dedicated servers do not load music. The source XM stays outside game exports under `docs/`.

This track is an external public-domain work; it is not an original FPSloppa composition.
