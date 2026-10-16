# Daytime ambience: second rooster correction — 2026-10-16

[Audition daytime replacement](day-audition.ogg), 25 seconds with +8dB review gain. [Full runtime loop](../../../deathmatch/audio/cq_field/forest_day.ogg).

The user confirmed the remaining rooster-like calls occur in daytime. Removing the Costa Rican layer alone had not solved the audible problem, despite the previous low classifier score. This change removes **all three remaining daytime bird-call layers** (Peruvian daytime, Lacandon and jungleathmo) rather than relying on that classifier score or turning the ambience down. Nighttime is unchanged.

The replacement is a quiet insect-focused bed from the already cached [Night Crickets Back Porch recording](https://freesound.org/people/hdfreema/sounds/333221/) by hdfreema, CC0. The source page/license was checked. This is a North American field recording used as a generic insect bed; it is not claimed to be geographically authentic Amazon wildlife. The cached source is the public HQ MP3 preview.

Source 60–188s is trimmed offline, edited through Audacity MCP with 1.8kHz high-pass / 8.5kHz low-pass, exported as a stereo master and finished with an eight-second equal-power loop join, DC removal and the existing quiet -32dBFS target. Runtime remains 120 seconds, stereo, 24kHz Vorbis. Encoded RMS is approximately -31.32dBFS, peak -17.24dBFS; runtime ambience gain/settings are unchanged. [Authoring operations and hashes](audacity-edits.json).

[Audio quality](quality.json) passes for all 51 runtime assets; the quality tool also includes an older general mixer recording as a 52nd entry, not a new playback capture of this ambience. [Isolated PCK import validation](pack.log) passes all 51 streams. No automatic bird classifier is used as proof of perceptual removal. The final runtime contains none of the previously used daytime bird recordings.

The recipe and manifest record the replacement and preserve credits/source hashes for the earlier recordings. `reauthor_jungle.py --period day` reproduces the filtering/looping from cached night.mp3 without requiring the old original bird WAVs. `--master-dir` consumes the actual Audacity export instead. The full build still needs the original sources for the unchanged nighttime mix.
