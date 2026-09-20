"""Campaign-wide admission and ordered reinforcement placement."""
import concurrent.futures
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from . import campaign, config, model
from .store import SQLiteStore
from .world import atlas


class AdmissionTest(unittest.TestCase):
    def setUp(self):
        self.state = model.initial(atlas())
        self.now = 100.
        for gateway in sorted({r['gateway'] for r in self.state['districts'].values()}):
            self.call('register_gateway', gateway)
            self.call('heartbeat', gateway, workers={d: 'worker'+d for d, r in self.state['districts'].items() if r['gateway']==gateway})

    def call(self, op, gateway, **fields):
        return model.apply(self.state, dict(op=op, session=gateway, **fields), gateway, self.now)

    def join(self, key, district='d10', team=0):
        return self.call('join', self.state['districts'][district]['gateway'], actor=key, resume=key, district=district, team=team)

    def request(self, key, op, **fields):
        return self.call(op, self.state['actors'][key]['gateway'], actor=key, resume=key, **fields)

    def wait_at(self, district):
        self.join('respawn', district)
        if self.state['actors']['respawn']['phase']=='active':
            self.request('respawn', 'wait')

    def no_allies(self):
        for d, row in self.state['districts'].items():
            if row['threshold']:
                self.state['campaign']['owners'][d] = 1

    def test_global_cap_includes_waiting_and_preserves_resume_and_transfer(self):
        for i in range(128):
            d = f'd{i%81:02}'
            team = max(0, self.state['districts'][d]['initial_owner'])
            self.join(f'a{i}', d, team)
        self.assertTrue(any(a['phase']=='waiting' for a in self.state['actors'].values()))
        with self.assertRaisesRegex(model.Rejected, 'Global player limit'):
            self.join('overflow', 'd40')
        # A transfer consumes two district reservations but just one identity.
        self.request('a0', 'begin', target='d01', tx='handoff')
        self.assertEqual(len(self.state['actors']), 128)
        self.assertEqual(self.join('a0', 'd00')['phase'], 'moving')
        self.request('a0', 'prepared', digest='a'*64, tx='handoff')
        self.request('a0', 'commit', tx='handoff')
        self.request('a0', 'finish', tx='handoff')
        self.assertEqual(self.request('a0', 'resume')['district'], 'd01')
        self.request('a0', 'leave')
        self.join('replacement', 'd40')
        view = model.view(self.state, None, self.now)
        self.assertEqual((view['player_count'], view['player_limit'], view['district_capacity']), (128,128,16))

    def test_persisted_database_atomic_admission_across_regions(self):
        # Simulate a pre-upgrade database (no stored player-limit field).
        for i in range(120):
            self.join(f'a{i}')
        with tempfile.TemporaryDirectory() as tmp, patch('tools.district_cluster.store.time.time', return_value=self.now):
            path = Path(tmp)/'state.sqlite'
            store = SQLiteStore(path, self.state)
            store.db.close()
            store = SQLiteStore(path, model.initial(atlas()))
            def attempt(i):
                d = f'd{i:02}'
                gateway = self.state['districts'][d]['gateway']
                try:
                    store.execute(dict(op='join', session=gateway, actor=f'race{i}', resume=f'race{i}', district=d, team=0), gateway)
                    return True
                except model.Rejected as e:
                    self.assertIn('Global player limit', str(e))
                    return False
            try:
                with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
                    self.assertEqual(sum(pool.map(attempt, range(24))), 8)
                self.assertEqual(store.execute(dict(op='status'), None)['player_count'], 128)
            finally:
                store.db.close()

    def test_allied_priority_over_nearer_neutral(self):
        self.wait_at('d40')
        self.no_allies()
        self.state['campaign']['owners']['d00'] = 0
        self.assertEqual(self.request('respawn', 'deploy')['district'], 'd00')

    def test_neutral_hub_fallback_after_last_allied_spawn_lost(self):
        self.wait_at('d40')
        self.no_allies()
        self.assertEqual(self.request('respawn', 'deploy')['district'], 'd40')

    def test_full_offline_draining_allies_and_neutral_capacity(self):
        for i in range(16):
            self.join(f'full{i}', 'd10')
            self.join(f'hub{i}', 'd40')
        self.wait_at('d10')
        self.no_allies()
        owners = self.state['campaign']['owners']
        for d in ('d10','d11','d19'):
            owners[d] = 0
        self.state['workers']['d11']['until'] = 0
        self.state['districts']['d19']['draining'] = True
        # Prefer the death site's nearest neutral outskirts, respecting leases.
        self.state['districts']['d03']['draining'] = True
        self.assertEqual(self.request('respawn', 'deploy')['district'], 'd12')
        self.assertEqual(model.counts(self.state)['d10'], 16)
        self.assertEqual(model.counts(self.state)['d40'], 16)

    def test_neutral_capture_districts_excluded_and_wait_until_slot_available(self):
        self.wait_at('d40')
        self.no_allies()
        for d, row in self.state['districts'].items():
            if row['campaign_role'] in ('hub','outskirts'):
                row['draining'] = True
            if row['campaign_role']=='relay':
                self.state['campaign']['owners'][d] = -1
        self.assertEqual(self.request('respawn', 'deploy')['phase'], 'waiting')
        # Nearest eligible relay perimeter opens, then sixteen independent slots
        # fill atomically. The next reinforcement must remain in its instance.
        self.state['districts']['d12']['draining'] = False
        self.assertEqual(self.request('respawn', 'deploy')['district'], 'd12')
        for i in range(16):
            key = f'waiting{i}'
            self.join(key, 'd40')
            result = self.request(key, 'deploy')
            self.assertEqual(result['phase'], 'active' if i<15 else 'waiting')
        self.assertEqual(model.counts(self.state)['d12'], 16)
        self.request('respawn', 'leave')
        self.assertEqual(self.request('waiting15', 'deploy')['district'], 'd12')

    def test_cli_defaults_to_campaign_but_generic_is_explicit(self):
        with tempfile.TemporaryDirectory() as tmp:
            for args, count, enabled in (([],81,True), (['--districts','4'],4,False)):
                path = Path(tmp)/f'{count}.json'
                subprocess.run([sys.executable,'-m','tools.district_cluster','init','--config',str(path),*args], check=True)
                value = config.read(path)
                self.assertEqual(len(value['districts']), count)
                self.assertEqual(campaign.enabled(value), enabled)


if __name__ == '__main__':
    unittest.main()
