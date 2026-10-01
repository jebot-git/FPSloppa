import copy
import json
from pathlib import Path
import tempfile
import unittest

from analyze import distribution, summarize, compare
from prepare import wrap
from run import matrix
from thread_compare import project_settings, driver_source

class Tests(unittest.TestCase):
    def test_thread_settings_are_isolated_and_replace_existing_keys(self):
        source='[application]\nrun/main_scene="res://game.tscn"\n[physics]\n3d/run_on_separate_thread=false\n[rendering]\ndriver/threads/thread_model=1\n'
        changed=project_settings(source,'res://fixture.tscn','both')
        self.assertIn('run/main_scene="res://fixture.tscn"',changed)
        self.assertIn('3d/run_on_separate_thread=true',changed)
        self.assertIn('driver/threads/thread_model=2',changed)
        self.assertEqual(changed.count('3d/run_on_separate_thread='),1)
        self.assertEqual(changed.count('driver/threads/thread_model='),1)
        self.assertIn('run/main_scene="res://game.tscn"',source)

    def test_release_thread_fixture_uses_main_scene_callbacks(self):
        source=driver_source()
        self.assertTrue(source.startswith('extends Node\n'))
        self.assertIn('func _ready() -> void:',source)
        self.assertIn('func _process(delta: float) -> void:',source)
        self.assertNotIn('return false',source)
        self.assertIn('vest.enabled=false',source)

    def test_true_median_and_nearest_rank_tails(self):
        self.assertEqual(distribution([1,2,4,100]),{'n':4,'p50':3,'p95':100,'p99':100,'max':100})
        self.assertIsNone(distribution([]))

    def test_balanced_capture_matrix(self):
        self.assertEqual(matrix('overhead',2),[('none','full'),('immediate','full'),('buffered','full'),('buffered','full'),('immediate','full'),('none','full')])

    def test_instrumentation_requires_existing_signature(self):
        with self.assertRaises(ValueError):wrap('func renamed():\n\tpass\n','sample','')
        result=wrap('func sample() -> Dictionary:\n\treturn {}\n','sample','')
        self.assertIn('return suite_result',result)
        self.assertIn('func suite_sample()',result)

    def fixture(self, root):
        meta={'complete':True,'frames':2,'budget_hz':72,'config':{'source_hash':'a','rules':'cs16','seconds':1,'warmup':0,'live':False,'capture':'none','stage':'timing','variant':'full'}}
        for key in ('engine','renderer','gpu','viewport','xr','refresh_hz','render_size','presentation','haptics','avatar_hashes'):meta[key]='fixture'
        (root/'metadata.json').write_text(json.dumps(meta))
        frames=[{'ticks_us':i*20000,'frame_ms':ms,'process_ms':2,'physics_ms':1,'render_cpu_ms':1,'render_gpu_ms':0,'previous_capture_ms':0,'menu':False,'active':True,'weapon':3,'rules':'cs16'} for i,ms in enumerate([10,20])]
        (root/'frames.jsonl').write_text('\n'.join(map(json.dumps,frames)))
        (root/'events.jsonl').write_text('')
        return meta

    def test_unavailable_gpu_budget_and_mismatched_comparisons(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name);self.fixture(root);report=summarize(root)
            self.assertIsNone(report['timings']['render_gpu_ms'])
            self.assertEqual(report['timings']['frame_ms']['p50'],15)
            self.assertEqual(report['over_budget_pct'],50)
            other=copy.deepcopy(report);other['metadata']['config']['source_hash']='b'
            with self.assertRaises(ValueError):compare([report,other])

    def test_rejects_failed_avatar_isolation(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name);meta=self.fixture(root);meta['config']['variant']='frozen'
            (root/'metadata.json').write_text(json.dumps(meta))
            frames=[json.loads(line) for line in (root/'frames.jsonl').read_text().splitlines()]
            frames[0]['scopes']={'rig':[100,1]}
            (root/'frames.jsonl').write_text('\n'.join(map(json.dumps,frames)))
            with self.assertRaises(ValueError):summarize(root)

    def test_rejects_partial_and_truncated_captures(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name);meta=self.fixture(root);meta['complete']=False
            (root/'metadata.json').write_text(json.dumps(meta))
            with self.assertRaises(ValueError):summarize(root)
            meta['complete']=True;meta['frames']=3
            (root/'metadata.json').write_text(json.dumps(meta))
            with self.assertRaises(ValueError):summarize(root)

if __name__=='__main__':unittest.main()
