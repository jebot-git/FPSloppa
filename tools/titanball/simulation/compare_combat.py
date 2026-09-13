#!/usr/bin/env python3
"""Plot matched before/after matches and export the revised pickup manifest."""
import argparse, json, os, re
from pathlib import Path
os.environ.setdefault('MPLCONFIGDIR', '/tmp/fpsloppa-matplotlib')
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

p = argparse.ArgumentParser()
p.add_argument('--baseline', default='live')
p.add_argument('--revision', default='contact-r2')
p.add_argument('--seed', type=int, default=7129)
a = p.parse_args()
out = Path(__file__).resolve().parents[3] / 'test-results/titanball/simulation'
profiles = ['tf', 'ut99', 'doom']
fig, axes = plt.subplots(1, 3, figsize=(14, 4.5), sharex=True, sharey=True)
new = {}
for ax, profile in zip(axes, profiles):
    for name, label, colour, style in [(a.baseline, 'Previous', '#898989', '--'), (a.revision, 'Revised', '#1766a0', '-')]:
        d = json.loads((out / f'{name}-{profile}-{a.seed}.json').read_text())
        if name == a.revision:
            new[profile] = d
        ss = d['samples']
        ax.plot([s['time']-60 for s in ss], [s['distance'] for s in ss], style, color=colour, label=label)
        ax.scatter(d['seconds']-60, d['progress'], color=colour, s=25)
    for cp in [90, 190]:
        ax.axhline(cp, linestyle=':', color='#b0b0b0', linewidth=1)
    ax.set(title=profile.upper(), xlabel='Active time (seconds)', xlim=(0, 980), ylim=(0, 307))
    ax.grid(alpha=.15)
axes[0].set_ylabel('Route distance (m)')
axes[0].legend(loc='lower right')
fig.suptitle('TITANBALL 6v6 · same seed · hull protection, linked heat and revised classless pickups')
fig.tight_layout()
fig.savefig(out / f'{a.revision}-before-after.png', dpi=160)
plt.close(fig)

ut, doom = new['ut99']['placements'], new['doom']['placements']
assert len(ut) == len(doom) == 64
assert all(u['position'] == d['position'] for u, d in zip(ut, doom))
lines = ['# Revised classless weapon placement', '',
         'Same 64 positions in UT and Doom. Basic racks stay for other players; advanced caches and ammo unlock after preparation and respawn every 30 seconds.', '',
         '| # | Type | World position (m) | UT | Doom | Available after |',
         '|---:|---|---|---|---|---:|']
fig, ax = plt.subplots(figsize=(6, 10))
for i, (u, d) in enumerate(zip(ut, doom), 1):
    pos = [float(v) for v in re.findall(r'-?\d+(?:\.\d+)?', u['position'])]
    kind = 'Basic rack' if u['basic'] else u['kind'].title()
    lines.append(f"| {i} | {kind} | {u['position']} | {u['title']} | {d['title']} | {u['release_seconds']} s |")
    if u['kind'] != 'weapon':
        continue
    ax.scatter(pos[0], pos[2], marker='s' if u['basic'] else 'o', color='#1766a0' if u['basic'] else '#9b5e20', s=28)
    if not u['basic']:
        ax.annotate(str(i), (pos[0], pos[2]), xytext=(4, 2), textcoords='offset points', fontsize=7)
    if u['item'] == 9:
        ax.annotate('Only UT sniper', (pos[0], pos[2]), xytext=(15, -15), textcoords='offset points', fontsize=9, arrowprops={'arrowstyle': '->'})
ax.set(title='Revised pickups · blue: basic racks / brown: advanced\nNumbers refer to the placement table', xlabel='World X (m)', ylabel='World Z (m)')
ax.set_aspect('equal'); ax.grid(alpha=.2); fig.tight_layout()
fig.savefig(out / f'{a.revision}-pickup-layout.png', dpi=160)
(out / f'{a.revision}-pickup-layout.md').write_text('\n'.join(lines)+'\n')
print('Matched 64 positions; wrote comparison and placement artifacts.')
