import copy
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from . import config, model, status_page
from .store import SQLiteStore


class ProfilesTest(unittest.TestCase):
    def setUp(self):
        self.folder=tempfile.TemporaryDirectory();self.path=Path(self.folder.name)/'state.sqlite'
        self.store=SQLiteStore(self.path,model.initial(config.campaign()['districts']))
        self.now=100
        self.clock=patch('tools.district_cluster.store.time.time',side_effect=lambda:self.now);self.clock.start()
        self.register()

    def tearDown(self):
        self.store.db.close();self.clock.stop();self.folder.cleanup()

    def register(self):
        self.call('register_gateway')
        self.call('heartbeat',workers={'d40':'worker'})

    def call(self,op,gateway='g10',**fields):
        return self.store.execute(dict(op=op,session='g10',**fields),gateway)

    def join(self,secret='secret',**fields):
        return self.call('join',actor='persistent',resume=secret,district='d40',**fields)

    def test_logout_restart_identity_stats_avatar_and_team_persist(self):
        first=self.join(team=1,name='Saved name')
        self.call('heartbeat',workers={'d40':'worker'},stats={'d40':{'persistent':dict(generation=1,kills=7,deaths=3)}})
        self.call('set_avatar',None,actor='persistent',resume='secret',avatar='a'*64)
        self.call('leave',actor='persistent',resume='secret')
        self.assertEqual(self.call('status',None)['player_count'],0)
        self.store.db.close();self.store=SQLiteStore(self.path,model.initial(config.campaign()['districts']))
        with self.assertRaisesRegex(model.Rejected,'persistent identity secret'):self.join(secret='wrong')
        second=self.join(team=0,name='Changed by client')
        self.assertEqual((second['id'],second['team'],second['name']),(first['id'],1,'Saved name'))
        self.assertEqual(second['stats'],dict(kills=7,deaths=3));self.assertEqual(second['avatar'],'a'*64)
        self.assertEqual(second['generation'],2);self.assertEqual(second['joins'],2)

    def test_presence_and_idle_reclaim_preserve_latest_profile(self):
        self.join(team=0)
        self.call('heartbeat',workers={'d40':'worker'},stats={'d40':{'persistent':dict(generation=1,kills=17,deaths=2)}})
        self.now+=91
        self.register()
        # Rejoin may be the first operation that discovers an expired actor.
        second=self.join()
        self.assertEqual(second['stats']['kills'],17)
        self.call('heartbeat',workers={'d40':'worker'},presence=['persistent'])
        self.now+=89
        self.assertEqual(self.call('status',None)['player_count'],1)
        self.now+=2
        self.assertEqual(self.call('status',None)['player_count'],0)
        saved=self.store.db.execute('SELECT count(*) FROM players').fetchone()[0]
        self.assertEqual(saved,1)

    def test_worker_counters_are_fenced_and_public_client_cannot_supply_profile(self):
        self.join(team=0,stats={'kills':999},avatar='b'*64)
        self.call('heartbeat',workers={'d40':'worker'},stats={'d40':{'persistent':dict(generation=99,kills=999,deaths=999)}})
        actor=self.call('profile',None,actor='persistent',resume='secret')
        self.assertEqual(actor['stats']['kills'],0);self.assertEqual(actor['avatar'],'')
        with self.assertRaisesRegex(model.Rejected,'Master content'):
            self.call('set_avatar',actor='persistent',resume='secret',avatar='b'*64)

    def test_status_html_escapes_map_labels_and_excludes_private_data(self):
        self.join(team=0,name='SECRET_PLAYER_NAME')
        state=self.call('status',None)
        state['districts']['d40']['name']='<script>alert(1)</script>'
        page=status_page.render(state,self.now)
        self.assertNotIn('<script>',page);self.assertIn('&lt;script&gt;',page)
        self.assertNotIn('SECRET_PLAYER_NAME',page);self.assertNotIn('resume_hash',page)
        self.assertEqual(page.count('<article '),81)
        self.assertIn('Players 1 / 128',page)


if __name__=='__main__':unittest.main()
