"""Check operator rotations take precedence over bundled maplist files."""
import importlib.util
import json
import secrets
import subprocess
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("rcon", ROOT / "tools/rcon.py")
rcon = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rcon)
results = []
cases = [
    ("global", "", ["qsrc_dm7", "qsrc_dm2"]),
    ("specific", 'set cc_maplist "cc_basement cc_hyperborea"\n',
     ["cc_basement", "cc_hyperborea"]),
]
with tempfile.TemporaryDirectory(prefix="fpsloppa-rotation-") as temporary:
    folder = Path(temporary)
    for index, (name, specific, expected) in enumerate(cases):
        password = secrets.token_hex(20)
        port = 28914 + index * 2
        config = folder / "server.cfg"
        config.write_text(
            f"set net_ip 127.0.0.1\nset net_port {port}\n"
            'set sv_gametype cc\nset sv_gametypes "cc dm"\n'
            'set sv_maplist "qsrc_dm7 qsrc_dm2"\n'
            f'set rcon_password "{password}"\nset rcon_port {port + 1}\n'
            + specific
        )
        log = ROOT / f"test-results/cc/rotation-{name}.log"
        with log.open("w") as output:
            process = subprocess.Popen(
                ["godot", "--headless", "--xr-mode", "off", "--audio-driver",
                 "Dummy", "--path", str(ROOT), "--", "--server", "--config", str(config)],
                stdout=output, stderr=subprocess.STDOUT,
            )
            try:
                deadline = time.monotonic() + 45
                while "SERVER_CONFIG" not in log.read_text() and time.monotonic() < deadline and process.poll() is None:
                    time.sleep(.1)
                assert process.poll() is None and "SERVER_CONFIG" in log.read_text(), log.read_text()[-3000:]
                status = rcon.command("127.0.0.1", port + 1, password, "status")
                assert status["rotation"] == expected and status["map"] == expected[0], status
                assert rcon.command("127.0.0.1", port + 1, password, "mode dm")["ok"]
                status_dm = rcon.command("127.0.0.1", port + 1, password, "status")
                assert status_dm["rotation"] == ["qsrc_dm7", "qsrc_dm2"], status_dm
                assert "SCRIPT ERROR:" not in log.read_text() and "ERROR:" not in log.read_text(), log.read_text()[-3000:]
                results.append({"case": name, "cc_rotation": status["rotation"], "dm_rotation": status_dm["rotation"], "passed": True})
            finally:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
(ROOT / "docs/validation/cc-config-precedence.json").write_text(json.dumps(results, indent=2) + "\n")
print("ROTATION_PRECEDENCE_PASS", json.dumps(results))
