"""Check complete trial coverage, result integrity and unchanged runtime inputs."""
import argparse
import hashlib
import json
from pathlib import Path

from run import ROOT, cases


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--label', default='priority-20260912')
    args = parser.parse_args()
    folder = ROOT / 'test-results/ai-balance' / args.label
    report = json.loads((ROOT / 'docs/validation/ai-priority-balance.json').read_text())
    assert report['label'] == args.label and report['complete']
    expected = [case for phase in ['koth', 'ctf', 'as', 'tf', 'cc_if'] for case in cases(phase)]
    for key, options in expected:
        path = folder / (key + '.json')
        status = json.loads((folder / (key + '-status.json')).read_text())
        data = json.loads(path.read_text())
        assert status['passed'] and status['exit_code'] == 0 and not status['errors'], key
        assert digest(path) == status['result_sha256'], key
        for field in ['map', 'mode', 'seed', 'mirror', 'class_mix', 'seconds', 'minutes']:
            assert data['case'][field] == options[field], (key, field)
        assert len(data['bots']) == 8, key
        assert data['actual_map'] == options['map'], key
        if options['mode'] == 'as':
            progress = data['balance']['assault_progress']
            assert progress[-1]['finished'] and progress[-1]['leg'] == 1, key
            assert data['simulated_seconds'] <= options['seconds'] + .02, key
        else:
            assert abs(data['simulated_seconds'] - options['seconds']) < .02, key
        if options['mode'] in ['ctf', 'tf']:
            captures = sum(c['ended'] == 'capture' for c in data['balance']['flag_carriers'])
            assert captures == sum(data['score']), key
        if options['mode'] == 'if':
            assert data['balance']['freeze_rounds'] == sum(data['score']), key
    nav = json.loads((folder / '01-navigation-frozen.json').read_text())
    status = json.loads((folder / '01-navigation-frozen-status.json').read_text())
    assert status['passed'] and digest(folder / '01-navigation-frozen.json') == status['result_sha256']
    assert len(nav['trials']) == 12
    performed = [r for r in nav['trials'] if 'skipped' not in r]
    assert all(30 <= r['seconds'] < 30.04 for r in performed)
    inventory = json.loads((ROOT / 'docs/validation/ai-priority-runtime-inputs.json').read_text())
    project = Path(inventory['isolated_project'])
    for name, sha in inventory['files'].items():
        assert digest(project / name) == sha, name
    for name, sha in report['input_hashes'].items():
        assert digest(project / name) == sha, name
    for name, sha in report['raw_json_sha256'].items():
        assert digest(folder / name) == sha, name
    result = dict(passed=True, match_trials=len(expected), navigation_trials_performed=len(performed),
                  navigation_trials_skipped=len(nav['trials'])-len(performed),
                  runtime_files_unchanged=len(inventory['files']),
                  simulated_match_minutes=report['simulated_match_minutes'],
                  balance_receipt_sha256=digest(ROOT / 'docs/validation/ai-priority-balance.json'),
                  checks=['Declared trial matrix and duration', 'Normal completion of both Assault legs',
                          'Observed captures and freeze-round events agree with scores',
                          'Navigation trial durations and explicit skips',
                          'Raw result hashes and unchanged isolated runtime inputs'])
    (ROOT / 'docs/validation/ai-priority-verification.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
