"""Local Linux checks for the resume guard; never touches system services."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
import unittest
from run_vps_comparison import identity, resume, terminate_group


@unittest.skipUnless(Path('/proc/self/stat').exists(), 'Linux /proc is required')
class ResumeGuardTests(unittest.TestCase):
    def setUp(self):
        self.process = subprocess.Popen([sys.executable, '-c', 'import signal; signal.pause()'], start_new_session=True)
        self.original = identity(self.process.pid)

    def tearDown(self):
        if self.process.poll() is None:
            os.kill(self.process.pid, signal.SIGCONT)
        terminate_group(self.process)

    def wait_state(self, wanted):
        deadline = time.monotonic() + 2
        while time.monotonic() < deadline:
            value = identity(self.process.pid)
            if value and (value[1] in ['T', 't']) == wanted:
                return value
            time.sleep(.01)
        self.fail('Unexpected child suspension state')

    def test_original_process_resumes(self):
        os.kill(self.process.pid, signal.SIGSTOP)
        self.wait_state(True)
        self.assertTrue(resume(self.process.pid, self.original))
        self.wait_state(False)

    def test_reused_identity_is_not_resumed(self):
        os.kill(self.process.pid, signal.SIGSTOP)
        self.wait_state(True)
        self.assertFalse(resume(self.process.pid, ('wrong-start-time', 'S')))
        self.wait_state(True)

    def test_departed_process_is_not_resumed(self):
        self.process.terminate()
        self.process.wait(timeout=2)
        self.assertFalse(resume(self.process.pid, self.original))

    def test_candidate_group_is_terminated(self):
        terminate_group(self.process)
        self.assertIsNotNone(self.process.poll())


if __name__ == '__main__':
    unittest.main()
