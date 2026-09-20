import copy
import tempfile
import unittest
from pathlib import Path
from .config import grid
from . import model
from .store import SQLiteStore


class RulesTest(unittest.TestCase):
    def setUp(self):
        self.state=model.initial(grid(8)['districts'])
        self.now=100
        for gateway in ('g00','g01'):
            self.call('register_gateway',gateway,session=gateway)
            self.call('heartbeat',gateway,workers={d:'worker'+d for d,r in self.state['districts'].items() if r['gateway']==gateway})

    def call(self,op,gateway='g00',**fields):
        state=copy.deepcopy(self.state)
        value=model.apply(state,dict({'op':op,'session':gateway},**fields),gateway,self.now)
        self.state=state
        self.assertLessEqual(max(model.counts(state).values()),16)
        return value

    def join(self,key,district='d03'):
        return self.call('join',self.state['districts'][district]['gateway'],actor=key,resume=key,name=key,district=district)

    def test_capacity_race_and_reservation_release(self):
        for i in range(15):self.join('resident'+str(i),'d04')
        self.join('a');self.join('b')
        self.call('begin',actor='a',resume='a',target='d04',tx='txa')
        with self.assertRaises(model.Rejected):self.call('begin',actor='b',resume='b',target='d04',tx='txb')
        self.assertEqual(model.counts(self.state)['d03'],2)
        self.call('prepared',actor='a',resume='a',tx='txa',digest='a'*64)
        self.call('commit',actor='a',resume='a',tx='txa')
        self.assertEqual(model.counts(self.state)['d03'],2)
        with self.assertRaises(model.Rejected):self.call('abort',actor='a',resume='a',tx='txa')
        self.call('finish',actor='a',resume='a',tx='txa')
        self.assertEqual(model.counts(self.state)['d03'],1)
        self.call('finish',actor='a',resume='a',tx='txa')
        self.call('resume','g01',actor='a',resume='a')
        with self.assertRaises(model.Rejected):self.call('resume',actor='a',resume='a')

    def test_waiting_and_deployment(self):
        for i in range(16):self.join('resident'+str(i))
        actor=self.join('waiting')
        self.assertEqual(actor['phase'],'waiting')
        deployed=self.call('deploy',actor='waiting',resume='waiting')
        self.assertEqual(deployed['district'],'d02')
        self.assertEqual(model.counts(self.state)['d03'],16)

    def test_draining_and_hot_topology(self):
        self.join('a')
        self.call('drain',None,district='d03')
        self.assertFalse(model.view(self.state,None,self.now)['districts']['d03']['open'])
        self.assertEqual(self.join('b')['phase'],'waiting')
        rows=copy.deepcopy(self.state['districts']);rows['d03']['map_slot']=2
        with self.assertRaises(model.Rejected):self.call('topology',None,districts=rows)
        self.call('begin',actor='a',resume='a',target='d04',tx='t')
        # Draining residents can leave, but new arrivals cannot enter.
        self.join('c','d02')
        with self.assertRaises(model.Rejected):self.call('begin',actor='c',resume='c',target='d03',tx='u')

    def test_fencing(self):
        self.join('a')
        with self.assertRaises(model.Rejected):self.call('register_gateway',session='replacement')
        self.now+=7
        with self.assertRaises(model.Rejected):self.call('begin',actor='a',resume='a',target='d04',tx='t')
        self.call('register_gateway',session='replacement')
        with self.assertRaises(model.Rejected):self.call('heartbeat',workers={})

    def test_invalid_and_maximum_topologies(self):
        for n in (4,5,16,63,64):model.topology(grid(n)['districts'])
        for n in (3,65):
            with self.assertRaises(ValueError):grid(n)
        rows=grid(4)['districts'];rows['d00']['links'].clear()
        with self.assertRaises(model.Rejected):model.topology(rows)

    def test_delayed_authority_packet_does_not_renew_worker(self):
        import time
        from .fixture_worker import FixtureWorker
        worker=FixtureWorker(grid(4),'d00')
        worker.command(dict(op='authority',revision=1,valid_for=2,expires_at=time.time()-10,metadata={},actors={}))
        with self.assertRaisesRegex(ValueError,'lease expired'):
            worker.command(dict(op='input',id=1,generation=1,command={'seq':1}))

    def test_store_restart_and_rejected_write_rollback(self):
        with tempfile.TemporaryDirectory() as path:
            db=Path(path)/'control.db'
            store=SQLiteStore(db,model.initial(grid(4)['districts']))
            store.execute(dict(op='register_gateway',session='first'),'g00')
            revision=store.execute(dict(op='status'),None)['revision']
            with self.assertRaises(model.Rejected):store.execute(dict(op='drain',district='unknown'),None)
            recovered=SQLiteStore(db,model.initial(grid(8)['districts']))
            status=recovered.execute(dict(op='status'),None)
            self.assertEqual(len(status['districts']),4)
            self.assertEqual(status['revision'],revision)
            store.db.close();recovered.db.close()


if __name__=='__main__':unittest.main()
