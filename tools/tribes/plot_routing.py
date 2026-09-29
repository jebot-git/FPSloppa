#!/usr/bin/env python3
"""Top-down carrier traces and speed-loss locations from completed ST runs."""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
from report_routing import ENDINGS, json_lines, vector

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('folders', nargs=2, type=Path)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
fig, axes = plt.subplots(2, 2, figsize=(13, 11), constrained_layout=True)

def terrain(ax, name):
    """Lowest sampled walkable surface at each graph column, not visual terrain."""
    path = args.folders[0].parent / f'{name}-layout.json'
    if not path.exists():
        return
    layout = json.loads(path.read_text())
    points = layout['points']
    if isinstance(points, str):
        points = [vector(value) for value in re.findall(r'\([^()]+\)', points)]
    columns = {}
    for x, y, z in points:
        columns[x, z] = min(y, columns.get((x, z), y))
    ax.tricontour([p[0] for p in columns], [p[1] for p in columns],
                  list(columns.values()), levels=12, colors='#858585', linewidths=.45, alpha=.35)

for column, folder in enumerate(args.folders):
    for row, name in enumerate(['ctf_stonehenge', 'ctf_raindance']):
        ax = axes[row, column]; segments, speeds, losses, bases = [], [], Counter(), []
        terrain(ax, name)
        matches, seconds, captures = 0, 0., 0
        for completion in sorted(folder.glob(f'{name}-*/completion.json')):
            run = completion.parent; receipt = json.loads(completion.read_text())
            if receipt['exit_code'] not in (0, 2) or receipt['timed_out'] or receipt['script_errors'] or receipt['teams'] != [8, 8] or receipt['termination_reason'] not in ENDINGS:
                continue
            matches += 1; seconds += receipt['seconds']; captures += sum(receipt['scores'])
            if not bases:
                result = json.loads((run / 'result.json').read_text())
                bases = [vector(flag['position']) for flag in result['samples'][0]['flags']]
            previous = {}
            for point in json_lines(run / 'navigation.jsonl'):
                old = previous.get(point['id']); previous[point['id']] = point
                if point['goal'] != 'st:capture' or not old or old['goal'] != point['goal'] or old['serial'] != point['serial'] or point['seconds']-old['seconds'] > 2:
                    continue
                a, b = vector(old['position']), vector(point['position'])
                segments.append([(a[0], a[2]), (b[0], b[2])]); speeds.append(point['speed_kmh'])
            for event in json_lines(run / 'navigation-events.jsonl'):
                if event['kind'] == 'abrupt_speed_loss':
                    x, _, z = vector(event['position']); losses[round(x/16)*16, round(z/16)*16] += 1
        collection = LineCollection(segments, cmap='viridis', linewidths=.8, alpha=.65)
        collection.set_array(speeds); collection.set_clim(0, 110); ax.add_collection(collection)
        if losses:
            ax.scatter([p[0] for p in losses], [p[1] for p in losses],
                       s=[min(140, 10+count*1200/max(1,seconds)*12) for count in losses.values()],
                       facecolors='none', edgecolors='#cf4b42', linewidths=.8, alpha=.7)
        for team, base in enumerate(bases):
            ax.scatter([base[0]], [base[2]], marker='*', s=170, color=['#b42318','#175cd3'][team], edgecolors='white', linewidths=.5, zorder=5)
        extent = 420 if name.endswith('stonehenge') else 560
        ax.set_xlim(-extent,extent); ax.set_ylim(extent,-extent); ax.set_aspect('equal')
        label = {'baseline': 'Baseline', 'selected': 'Moving-launch candidate', 'guard': 'Final safeguard', 'refined': 'Rejected terrain experiment'}.get(folder.name, folder.name)
        ax.set_title(f'{label} · {name.removeprefix("ctf_")}\n{matches} runs · {captures} captures · {seconds/60:.1f} game minutes')
        ax.set_xlabel('X (metres)'); ax.set_ylabel('Z (metres)'); ax.grid(alpha=.15)
fig.colorbar(collection, ax=axes.ravel().tolist(), label='Carrier horizontal speed (km/h)', shrink=.75, extend='max')
fig.suptitle('Carrier return routes and abrupt speed losses\nLines: delivery travel. Red rings: losses per 20 game minutes. Stars: flag stands.\nGrey contours: sampled walkable collision heights (approximate).', fontsize=12)
fig.savefig(args.output, dpi=160, bbox_inches='tight', pad_inches=.15)
print(args.output)
