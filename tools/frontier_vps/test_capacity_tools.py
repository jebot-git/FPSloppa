"""Checks for deployment-pack preservation and owned-socket readiness."""
import hashlib
import json
from pathlib import Path
import socket
import struct
import subprocess
import sys
import tempfile
import unittest

from patch_probe_pack import entries
from run_capacity_case import listening


class CapacityToolsTests(unittest.TestCase):
    def test_readiness_requires_owned_socket(self):
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp:
            udp.bind(('127.0.0.1', 0))
            port = udp.getsockname()[1]
            import os
            self.assertTrue(listening(os.getpid(), port))
            self.assertFalse(listening(0, port))
        self.assertFalse(listening(os.getpid(), port))

    def test_pack_preserves_resources_and_replaces_registered_entry(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source, output = root/'original.pck', root/'probe.pck'
            overrides = root/'overrides'
            overrides.mkdir()
            (overrides/'host.gd').write_bytes(b'new host')
            original = {'host.gd': b'old host', 'map.bin': bytes(range(256))}
            header = bytearray(128)
            header[:4] = b'GDPC'
            struct.pack_into('<I', header, 4, 4)
            struct.pack_into('<IQQ', header, 20, 2, 128, 0)
            with source.open('wb') as stream:
                stream.write(header)
                rows = []
                for name, data in original.items():
                    path = name.encode()+b'\0'
                    path += b'\0'*((-len(path)) % 4)
                    rows.append((path, stream.tell()-128, len(data), hashlib.md5(data).digest()))
                    stream.write(data)
                directory = stream.tell()
                stream.write(struct.pack('<I', len(rows)))
                for path, offset, size, digest in rows:
                    stream.write(struct.pack('<I', len(path))+path+struct.pack('<QQ', offset, size)+digest+b'\0'*4)
                stream.seek(32)
                stream.write(struct.pack('<Q', directory))
            before = source.read_bytes()
            subprocess.run([sys.executable, str(Path(__file__).with_name('patch_probe_pack.py')),
                            '--source', str(source), '--output', str(output),
                            '--overrides', str(overrides)], check=True, capture_output=True)
            self.assertEqual(source.read_bytes(), before)
            with output.open('rb') as stream:
                _, base, _, rows = entries(stream)
                self.assertEqual(len(rows), 2)
                for path, offset, size, digest, _ in rows:
                    name = path.rstrip(b'\0').decode()
                    stream.seek(base+offset)
                    data = stream.read(size)
                    self.assertEqual(data, b'new host' if name == 'host.gd' else original[name])
                    self.assertEqual(hashlib.md5(data).digest(), digest)
            provenance = json.loads(output.with_suffix('.patch.json').read_text())
            self.assertEqual(provenance['source_sha256'], hashlib.sha256(before).hexdigest())
            self.assertEqual(provenance['output_sha256'], hashlib.sha256(output.read_bytes()).hexdigest())
            (overrides/'unregistered.gd').write_text('reject')
            rejected = subprocess.run([sys.executable, str(Path(__file__).with_name('patch_probe_pack.py')),
                                       '--source', str(source), '--output', str(root/'invalid.pck'),
                                       '--overrides', str(overrides)], capture_output=True)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn(b'Cannot add unregistered entries', rejected.stderr)


if __name__ == '__main__':
    unittest.main()
