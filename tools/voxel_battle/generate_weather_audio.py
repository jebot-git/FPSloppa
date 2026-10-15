"""Generate original deterministic, seamless rain and a distant thunder clap (no samples)."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[2] / 'deathmatch/audio/weather'
RATE = 22050


def write(name, values):
    peak = max(abs(v) for v in values)
    pcm = b''.join(struct.pack('<h', round(v / peak * 27000)) for v in values)
    with wave.open(str(ROOT / name), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm)


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    rng = random.Random(290421)
    count = RATE * 8
    noise = [rng.uniform(-1, 1) for _ in range(count)]
    # Circular filtering keeps both the waveform and its low band seamless.
    rain = [noise[i] * .65 + sum(noise[(i - k) % count] for k in range(1, 9)) * .045
            for i in range(count)]
    write('rain.wav', rain)
    thunder = []
    low = 0.0
    for i in range(RATE * 5):
        t = i / RATE
        low = low * .96 + rng.uniform(-1, 1) * .04
        envelope = min(1, t / .012) * math.exp(-t / 1.1) * min(1, (5 - t) / .3)
        roll = low * 3 + math.sin(t * 2 * math.pi * 43) * .055
        crack = rng.uniform(-1, 1) * math.exp(-t * 18) * .24
        thunder.append((roll + crack) * envelope)
    write('thunder.wav', thunder)


if __name__ == '__main__':
    main()
