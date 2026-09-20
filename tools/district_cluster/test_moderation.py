import copy,hashlib,unittest
from . import config,model,moderation
class ModerationTest(unittest.TestCase):
    def setUp(self):
        self.s=model.initial(config.campaign()['districts']);self.now=100;self.token='a'*64
        for g in ['g10','g03']:
            self.call('register_gateway',g)
            self.call('heartbeat',g,workers={d:'worker' for d,r in self.s['districts'].items() if r['gateway']==g})
        self.s['campaign']['owners']['d13']=0
        self.call('join',actor='mod',resume='secret',district='d41',team=0)
        self.call('join','g03',actor='target',resume='secret',district='d13',team=0)
        # Resident fixtures have already travelled out of the inner city.
        self.s['actors']['mod'].update(district='d41',gateway='g10',phase='active',generation=2)
        self.s['actors']['target'].update(district='d13',gateway='g03',phase='active',generation=2)
    def call(self,op,g='g10',**fields):
        s=copy.deepcopy(self.s)
        result=model.apply(s,dict(op=op,session=g,_moderator_config='cfg',**fields),g,self.now)
        self.s=s;return result
    def login(self):return self.call('moderator_login',actor='mod',resume='secret',_moderator_grant=self.token)
    def mod(self,op,**kw):return self.call(op,actor='mod',resume='secret',moderator_token=self.token,**kw)
    def test_disabled_and_secret_required(self):
        with self.assertRaises(ValueError):self.call('moderator_login',actor='mod',resume='secret')
        with self.assertRaises(ValueError):self.mod('moderator_list')
        self.login()
        with self.assertRaises(ValueError):self.call('moderator_list',actor='mod',resume='secret',moderator_token='wrong')
        self.assertNotIn('_moderator',model.public_actor(self.s['actors']['mod']))
        self.mod('moderator_logout')
        with self.assertRaises(ValueError):self.mod('moderator_list')
    def test_order_bypasses_gate_only_with_master_grant(self):
        self.login();r=self.mod('moderator_move',action='district',district='d13')
        with self.assertRaises(ValueError):self.call('begin',actor='mod',resume='secret',target='d13',tx='forged')
        a=self.call('begin',actor='mod',resume='secret',target='d13',tx='valid',order=r['order'])
        self.assertEqual(a['mod_transfer'],r['order'])
        self.call('prepared',actor='mod',resume='secret',tx='valid',digest='b'*64)
        self.call('commit',actor='mod',resume='secret',tx='valid')
        a=self.call('finish',actor='mod',resume='secret',tx='valid')
        self.assertEqual((a['district'],a['generation']),('d13',3));self.assertNotIn('mod_move',a)
        self.assertEqual(self.s['moderation_audit'][-1]['result'],'completed')
    def test_full_and_unavailable_destinations_rejected(self):
        self.login()
        for i in range(15):
            self.call('join','g03',actor=f'p{i}',resume='secret',district='d13',team=0)
            self.s['actors'][f'p{i}'].update(district='d13',gateway='g03',phase='active')
        with self.assertRaises(ValueError):self.mod('moderator_move',action='district',district='d13')
        with self.assertRaises(ValueError):self.mod('moderator_move',action='district',district='d00')
        self.assertEqual(model.counts(self.s)['d13'],16)
    def test_summon_anchor_and_expiry(self):
        self.login();self.mod('moderator_move',action='bring',player=self.s['actors']['target']['id'])
        a=self.s['actors']['target'];self.assertEqual(a['mod_move']['anchor'],self.s['actors']['mod']['id'])
        self.assertEqual(a['mod_move']['target'],'d41')
        a['mod_move']['until']=self.now-1
        with self.assertRaises(ValueError):self.call('begin','g03',actor='target',resume='secret',target='d41',tx='expired',order=a['mod_move']['id'])
    def test_voice_lease_is_single_speaker(self):
        self.login();v=self.mod('moderator_voice_claim');self.assertEqual(v['id'],self.s['actors']['mod']['id'])
        self.call('moderator_login','g03',actor='target',resume='secret',_moderator_grant='b'*64)
        with self.assertRaises(ValueError):self.call('moderator_voice_claim','g03',actor='target',resume='secret',moderator_token='b'*64)
        self.mod('moderator_logout');self.assertNotIn('global_voice',self.s)
    def test_password_rotation_invalidates_previous_session(self):
        self.login()
        with self.assertRaisesRegex(ValueError,'unauthorized'):
            model.apply(copy.deepcopy(self.s),dict(op='moderator_list',session='g10',actor='mod',resume='secret',moderator_token=self.token,_moderator_config='rotated'),'g10',self.now)
    def test_password_verifier(self):
        v=moderation.verifier('private testing password')
        self.assertTrue(moderation.verify('private testing password',v));self.assertFalse(moderation.verify('incorrect password',v))
class VoiceFanoutTest(unittest.IsolatedAsyncioTestCase):
    async def test_unreachable_region_does_not_stall_healthy_region(self):
        import asyncio
        from types import SimpleNamespace
        from unittest.mock import patch
        from .global_voice import GlobalVoice
        g=SimpleNamespace(name='source',config=dict(mesh_token='test',gateways=dict(slow=dict(address=['slow',1]),fast=dict(address=['fast',2]))))
        voice=GlobalVoice(g);delivered=[]
        async def fake_rpc(address,message):
            if address[0]=='slow':await asyncio.sleep(1)
            else:delivered.append(message['frame']['sequence'])
        with patch('tools.district_cluster.global_voice.rpc',fake_rpc):
            for i in range(6):
                voice.queue.put_nowait(dict(sequence=i));await voice.fanout();await asyncio.sleep(.01)
            self.assertEqual(delivered,list(range(6)));self.assertEqual(len(voice.deliveries),2)
            for task in voice.deliveries.values():task.cancel()
            await asyncio.gather(*voice.deliveries.values(),return_exceptions=True)

if __name__=='__main__':unittest.main()
