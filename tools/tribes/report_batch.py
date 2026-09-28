#!/usr/bin/env python3
"""Compact ledger of completed ST runs, retaining failed capture attempts."""
import argparse
import json
from pathlib import Path

from report_match import summarize


def ledger(root):
    rows = []
    for result in sorted(root.glob('*/result.json')):
        folder = result.parent
        report = summarize(folder)
        options_path = folder / 'options.json'
        options = json.loads(options_path.read_text()) if options_path.exists() else {}
        video_path = folder / 'video.json'
        video = json.loads(video_path.read_text()) if video_path.exists() else {}
        if not options.get('map'):
            # Early exploratory runs predate the options receipt. Mark this
            # inference and do not invent a missing seed or source revision.
            maps = [line.split()[1] for line in (folder / 'server.log').read_text().splitlines()
                    if line.startswith('MAP_READY ctf_')]
            options['map'] = maps[-1] if maps else None
        row = dict(run=folder.name, map=options.get('map'), seed=options.get('seed'),
                   options_recorded=options_path.exists(),
                   evidence=str(folder), recording=str(folder / 'match.mp4') if video else None,
                   video_clock_basis=video.get('clock_basis'),
                   behaviour=report['behaviour'], combat=report['combat'])
        for key in ('seconds', 'scores', 'first_capture_seconds', 'flag_pickups',
                    'termination_reason', 'post_capture_activity', 'script_errors',
                    'peak_horizontal_kmh', 'tactics', 'offense'):
            row[key] = report[key]
        # Detailed individual carries and deaths remain in each analysis.json.
        row['behaviour'] = {key: value for key, value in row['behaviour'].items()
                            if key in ('travel_median_kmh', 'travel_p90_kmh')}
        row['combat'] = {key: value for key, value in row['combat'].items()
                        if key != 'fatal_carrier_events'}
        (folder / 'analysis.json').write_text(json.dumps(report, indent=2) + '\n')
        rows.append(row)
    return dict(runs=rows, note='Exploratory iterations with different code/seeds; '
                'not a controlled statistical comparison. Failed runs are retained. '
                'Only completed result.json runs are included.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.write_text(json.dumps(ledger(args.root), indent=2) + '\n')
