"""Render Copper Fuse, an original orchestral action XM for DE.

Editable MilkyTracker score from compose_de_orchestral.py, with CC0 recordings. Requires NumPy and FFmpeg. --install selects the game asset.
No reference soundtrack audio or transcribed melody is used.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/audio/copper-fuse"
SAMPLES = OUT / "samples"
MUSIC = ROOT / "deathmatch/audio/music"
RATE, BPM, BARS = 44100, 150, 64
BEAT = 60 / BPM
N = round(BARS * 4 * BEAT * RATE)
EVENTS = []


def compose():
    import compose_de_orchestral as orchestra
    audio = orchestra.render()
    EVENTS.extend(orchestra.EVENTS)
    return audio


def write(path, x):
    with wave.open(str(path), "wb") as f:
        f.setparams((2, 2, RATE, 0, "NONE", "not compressed"))
        f.writeframes(np.rint(np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())


def measure(path):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(path), "-af", "loudnorm=I=-20:TP=-3:LRA=10:print_format=json", "-f", "null", "-"], capture_output=True, text=True, check=True)
    return json.JSONDecoder().raw_decode(r.stderr[r.stderr.rfind("{"):])[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__);parser.add_argument("--install", action="store_true");args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    mixed = compose();assert np.isfinite(mixed).all()
    raw = ROOT / "test-results/defusal/copper-fuse-raw.wav";write(raw, mixed * .9 / max(1, float(np.abs(mixed).max())))
    stats = measure(raw)
    norm = "loudnorm=I=-20:TP=-3:LRA=10:linear=true" + "".join(":" + k + "=" + stats[v] for k, v in [("measured_I", "input_i"), ("measured_TP", "input_tp"), ("measured_LRA", "input_lra"), ("measured_thresh", "input_thresh"), ("offset", "target_offset")])
    # Vorbis overlap can ring beyond a sub-millisecond fade; short codec-edge
    # ramps keep the decoded loop seam quiet while preserving the beat grid.
    norm += f",afade=t=in:d=0.012,afade=t=out:st={N / RATE - .015:.9f}:d=0.015"
    dest = MUSIC / "copper_fuse.ogg" if args.install else OUT / "Copper-Fuse.ogg"
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(raw), "-af", norm, "-ar", str(RATE), "-c:a", "libvorbis", "-q:a", "5", "-metadata", "title=Copper Fuse", "-metadata", "artist=FPSloppa original music", "-metadata", "comment=Original CC0 composition and arrangement; 64-bar DE loop", str(dest)], check=True)
    audio = np.frombuffer(subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(dest), "-ar", str(RATE), "-ac", "2", "-f", "f32le", "-"]), "<f4").reshape(-1, 2)
    measured = measure(dest);seam = float(np.abs(audio[0] - audio[-1]).max())
    assert np.isfinite(audio).all() and len(audio) == N and float(np.abs(audio).max()) < 1
    assert abs(float(measured["input_i"]) + 20) < .6 and float(measured["input_tp"]) <= -2.8 and seam < .003
    write(ROOT / "test-results/defusal/copper-fuse-boundary.wav", np.concatenate([audio[-6 * RATE:], audio[:6 * RATE]]))
    row = dict(key="de", stem="copper_fuse", title="Copper Fuse", bpm=BPM, bars=BARS, duration=N / RATE, ogg_bytes=dest.stat().st_size, sha256=hashlib.sha256(dest.read_bytes()).hexdigest(), target_lufs=-20, measured_lufs=float(measured["input_i"]), true_peak_dbtp=float(measured["input_tp"]), loop=True, loop_offset=0, loop_step=seam, sample_rate=RATE, license="CC0-1.0", generator="tools/generate_de_music.py --install", source_file="copper_fuse.score.json", source_format="recorded-sample-and-synthesis-arrangement")
    import compose_de_orchestral as orchestra
    row.update(orchestra.metadata())
    (MUSIC / "copper_fuse.score.json" if args.install else OUT / "score.json").write_text(json.dumps(dict(row, events=EVENTS), indent=2) + "\n")
    if args.install:
        rows = [r for r in json.loads((MUSIC / "scores.json").read_text()) if r["key"] != "de"] + [row]
        (MUSIC / "scores.json").write_text(json.dumps(rows, indent=2) + "\n")
    print(json.dumps(row, indent=2))


if __name__ == "__main__":main()
