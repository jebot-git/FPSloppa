"""Author the original, mono flamethrower jet; no third-party recordings.
The 240 ms burst crossfades with the weapon's 120 ms firing cadence.
"""
from pathlib import Path
import array, math, random, subprocess, wave
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test-results/flamethrower-audio'
OUT.mkdir(parents=True, exist_ok=True)
rate = 22050
rng = random.Random(59172)
slow = fast = 0.0
samples = []
for i in range(round(rate * .24)):
    t = i / rate
    noise = rng.uniform(-1, 1)
    slow += .025 * (noise - slow)
    fast += .23 * (noise - fast)
    roar = fast * .8 + slow * 3.5 + math.sin(2 * math.pi * 73 * t) * .10
    envelope = min(1, t / .035, (.24 - t) / .09)
    samples.append(roar * max(0, envelope))
peak = max(abs(v) for v in samples)
pcm = array.array('h', (round(v / peak * 21000) for v in samples))
wav = OUT / 'flamethrower.wav'
with wave.open(str(wav), 'wb') as target:
    target.setnchannels(1)
    target.setsampwidth(2)
    target.setframerate(rate)
    target.writeframes(pcm.tobytes())
script = OUT / 'save.gd'
script.write_text('''extends SceneTree
func _initialize():
 var stream=AudioStreamWAV.load_from_file("%s")
 assert(stream!=null)
 var result=ResourceSaver.save(stream,"res://deathmatch/audio/flamethrower.res",ResourceSaver.FLAG_COMPRESS)
 assert(result==OK)
 print("FLAMETHROWER_AUDIO_SAVED ",stream.get_length());quit()
''' % wav)
subprocess.run(['godot', '--headless', '--xr-mode', 'off', '--path', str(ROOT),
                '--log-file', str(OUT / 'generate.log'), '--script', str(script)], check=True)
