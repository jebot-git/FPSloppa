import copy
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from . import model, campaign
from .world import atlas
from .store import SQLiteStore


class CampaignTest(unittest.TestCase):
    def setUp(self):
        self.state=model.initial(atlas());self.now=100.
        campaign.advance(self.state,self.now)

    def actor(self,key,team,district):
        self.state['actors'][key]=dict(id=1000+len(self.state['actors']),team=team,district=district,preferred=district,phase='active',generation=1,gateway=self.state['districts'][district]['gateway'],arrival=None)

    def report(self,district,keys):
        c=self.state['campaign'];old=c['reports'].get(district,{})
        campaign.report(self.state,district,dict(epoch=c['epoch'],sequence=old.get('sequence',0)+1,actors={k:self.state['actors'][k]['generation'] for k in keys},received_at=self.now),'worker',self.now)
        campaign.advance(self.state,self.now)

    def step(self,seconds,district=None,keys=()):
        for _ in range(seconds*2):
            if district:self.report(district,keys)
            self.now+=.5;campaign.advance(self.state,self.now)

    def test_layout(self):
        from collections import Counter
        rows=atlas();model.topology(rows)
        self.assertEqual(Counter(r['campaign_role'] for r in rows.values()),dict(homebase=4,perimeter=32,relay=4,hub=1,outskirts=40))
        self.assertEqual([rows[d]['initial_owner'] for d in ('d10','d16','d64','d70')],[0,1,1,0])
        self.assertEqual(sum(len(r['links']) for r in rows.values()),288)
        self.assertEqual(len(rows['d40']['terminals']),4)
        for d,r in rows.items():
            if r['campaign_role']=='homebase':self.assertEqual(len(r['perimeter']),8)

    def test_capture_contested_absent_and_stale(self):
        self.actor('red',0,'d13');self.actor('blue',1,'d13')
        self.step(8,'d13',['red']);self.assertEqual(self.state['campaign']['points']['d13'],[8.,0.])
        self.step(4,'d13',['red','blue']);self.assertEqual(self.state['campaign']['points']['d13'],[8.,0.])
        self.step(3,'d13',['blue']);self.assertEqual(self.state['campaign']['points']['d13'],[0.,3.])
        self.step(27,'d13',['blue']);self.assertEqual(self.state['campaign']['owners']['d13'],1)
        self.assertEqual(self.state['campaign']['points']['d13'],[0.,0.])
        self.step(4,'d13',['red']);self.step(2)
        self.assertEqual(self.state['campaign']['points']['d13'],[0.,0.])
        old=copy.deepcopy(self.state['campaign']['reports']['d13']);old['received_at']=self.now
        campaign.report(self.state,'d13',dict(old,epoch=1),'worker',self.now)
        self.assertEqual(self.state['campaign']['reports']['d13']['until'],old['until'])

    def test_homebase_entry_and_terminal(self):
        c=self.state['campaign'];blue={'team':1}
        self.assertFalse(campaign.can_enter(self.state,blue,'d10'))
        for p in self.state['districts']['d10']['perimeter']:c['owners'][p]=1
        self.assertTrue(campaign.can_enter(self.state,blue,'d10'))
        self.assertFalse(campaign.can_enter(self.state,blue,'d13','d40'))
        c['owners']['d13']=1;self.assertTrue(campaign.can_enter(self.state,blue,'d13','d40'))
        c['owners']['d00']=0;self.assertFalse(campaign.can_enter(self.state,blue,'d10'))

    def test_lockdown_restarts_hold_and_blocks_capture(self):
        c=self.state['campaign'];campaign.advance(self.state,3700)
        self.assertEqual(c['locks']['d10']['until'],7300)
        self.now=3700;self.actor('blue',1,'d00');self.step(20,'d00',['blue'])
        self.assertEqual(c['owners']['d00'],0)
        campaign.advance(self.state,7300);self.assertNotIn('d10',c['locks'])
        self.assertEqual(c['holds']['d10']['since'],7300)
        campaign.advance(self.state,10899);self.assertNotIn('d10',c['locks'])
        campaign.advance(self.state,10900);self.assertIn('d10',c['locks'])

    def test_hold_interrupted(self):
        campaign.advance(self.state,2000);self.state['campaign']['owners']['d00']=1
        campaign.advance(self.state,2001);self.assertNotIn('d10',self.state['campaign']['holds'])
        campaign.advance(self.state,2100);self.state['campaign']['owners']['d00']=0;campaign.advance(self.state,2100)
        campaign.advance(self.state,5699);self.assertNotIn('d10',self.state['campaign']['locks'])
        campaign.advance(self.state,5700);self.assertIn('d10',self.state['campaign']['locks'])

    def test_midnight_once_restart_and_campaign_reset(self):
        self.actor('red',0,'d10');self.state['campaign']['scores']=[18,8]
        with tempfile.TemporaryDirectory() as tmp:
            store=SQLiteStore(Path(tmp)/'state.sqlite',self.state)
            with patch('tools.district_cluster.store.time.time',return_value=86399):
                self.assertEqual(store.execute({'op':'status'},None)['campaign']['scores'],[18,8])
            with patch('tools.district_cluster.store.time.time',return_value=86400):
                first=store.execute({'op':'status'},None)
                self.assertEqual(first['campaign']['epoch'],2);self.assertEqual(first['campaign']['scores'],[0,0])
                self.assertEqual(first['campaign']['history'][-1]['scores'],[20,10])
                self.assertEqual(first['campaign']['history'][-1]['winner'],0)
                self.assertEqual(first['actors']['red']['phase'],'waiting')
                store.db.close();store=SQLiteStore(Path(tmp)/'state.sqlite',model.initial(atlas()))
                self.assertEqual(store.execute({'op':'status'},None)['campaign']['history'],first['campaign']['history'])
            store.db.close()

    def test_simultaneous_threshold_is_draw_and_catchup(self):
        campaign.advance(self.state,10*86400)
        c=self.state['campaign'];self.assertEqual(c['epoch'],2)
        self.assertEqual(c['history'][0]['winner'],-1)
        self.assertEqual(c['history'][0]['scores'],[20,20])
        self.assertEqual(c['scores'],[0,0])

    def test_capacity_team_respawn_and_no_owned_spawn(self):
        # Use real metadata operations, including gateway fencing and waiting.
        s=self.state;now=self.now
        for g in {r['gateway'] for r in s['districts'].values()}:
            model.apply(s,dict(op='register_gateway',session=g),g,now)
            model.apply(s,dict(op='heartbeat',session=g,workers={d:'worker'+d for d,r in s['districts'].items() if r['gateway']==g}),g,now)
        for i in range(17):
            a=model.apply(s,dict(op='join',session='g02',actor=f'r{i}',resume=f'r{i}',district='d10',team=0),'g02',now)
        # Move admitted residents to the homebase to exercise reinforcement capacity.
            a=s['actors'][f'r{i}'];a.update(district='d10' if i<16 else None,phase='active' if i<16 else 'waiting',gateway='g02',preferred='d10');a.pop('entry_kind',None)
        self.assertEqual(a['phase'],'waiting');self.assertEqual(model.counts(s)['d10'],16)
        a=model.apply(s,dict(op='deploy',session='g02',actor='r16',resume='r16'),'g02',now)
        self.assertEqual(a['district'],'d01') # BFS tie-break, adjacent owned district.
        model.apply(s,dict(op='wait',session=a['gateway'],actor='r16',resume='r16'),a['gateway'],now)
        for d in s['campaign']['owners']:s['campaign']['owners'][d]=1
        a=model.apply(s,dict(op='deploy',session=a['gateway'],actor='r16',resume='r16'),a['gateway'],now)
        self.assertEqual(a['phase'],'waiting')

    def test_gate_relocks_before_commit_and_reset_during_transfer(self):
        s=self.state;now=self.now
        for g in ('g02','g00'):
            model.apply(s,dict(op='register_gateway',session=g),g,now)
            model.apply(s,dict(op='heartbeat',session=g,workers={d:'worker'+d for d,r in s['districts'].items() if r['gateway']==g}),g,now)
        for d in s['districts']['d10']['perimeter']:s['campaign']['owners'][d]=1
        model.apply(s,dict(op='join',session='g00',actor='blue',resume='secret',district='d01',team=1),'g00',now)
        s['actors']['blue'].update(district='d01',gateway='g00',phase='active') # Existing player at the perimeter gate.
        auth=dict(session='g00',actor='blue',resume='secret',tx='crossing')
        model.apply(s,dict(op='begin',target='d10',**auth),'g00',now)
        model.apply(s,dict(op='prepared',digest='a'*64,**auth),'g00',now)
        s['campaign']['owners']['d00']=0
        with self.assertRaises(model.Rejected):model.apply(s,dict(op='commit',**auth),'g00',now)
        self.assertEqual(model.counts(s)['d10'],1)
        campaign.reset(s,now,[0])
        a=model.apply(s,dict(op='abort',**auth),'g00',now)
        self.assertEqual(a['phase'],'waiting');self.assertEqual(model.counts(s)['d10'],0)

if __name__=='__main__':unittest.main()
