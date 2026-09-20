import tempfile
import unittest
from pathlib import Path
from . import config, deploy

ROOT=Path(__file__).resolve().parents[2]

class DeploymentTest(unittest.TestCase):
    def test_profiles_cover_atlas_and_keep_region_assignments_together(self):
        for name,workers in (('live.cfg',7),('compact.cfg',3)):
            cluster,nodes,masters,ingress=deploy.read(ROOT/'deploy/cq'/name)
            self.assertEqual(sum(r['role']=='workers' for r in nodes.values()),workers)
            self.assertEqual(len(masters),1)
            self.assertEqual(nodes[ingress]['role'],'ingress')
            self.assertEqual(sum(len(r.get('districts',[])) for r in nodes.values()),81)

    def test_missing_or_duplicate_district_rejected(self):
        original=(ROOT/'deploy/cq/live.cfg').read_text()
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'bad.cfg'
            for text in (original.replace('d00-d11','d00-d10'),original.replace('d12-d23','d11-d23')):
                path.write_text(text)
                with self.assertRaises(ValueError):deploy.read(path)

    def test_private_network_validation(self):
        for host in ('127.0.0.1','10.77.0.10','172.16.1.2','192.168.2.3'):self.assertTrue(config.private_host(host))
        for host in ('0.0.0.0','45.147.228.101','198.51.100.1','example.com'):self.assertFalse(config.private_host(host))

if __name__=='__main__':unittest.main()
