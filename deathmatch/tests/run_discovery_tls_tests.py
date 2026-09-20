"""Exercise HTTPS trust/hostname checks in the compiled console server runtime."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import ssl
import subprocess
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("fpsloppa_master", ROOT / "tools/master_server/server.py")
master = importlib.util.module_from_spec(spec)
spec.loader.exec_module(master)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--server", type=Path, default=ROOT / "Builds/ConsoleServer/FPSloppaServer.x86_64")
    args = parser.parse_args()
    logs = ROOT / "test-results/discovery-tls"
    logs.mkdir(parents=True, exist_ok=True)
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot")
    with tempfile.TemporaryDirectory(prefix="fpsloppa-tls-") as temporary:
        folder = Path(temporary)
        env = dict(os.environ, XDG_DATA_HOME=str(folder / "data"))
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                        "-subj", "/CN=FPSloppa test", "-addext", "subjectAltName=IP:127.0.0.1",
                        "-keyout", str(folder / "key.pem"), "-out", str(folder / "cert.pem")],
                       check=True, capture_output=True)
        service = master.Server(("127.0.0.1", 0), master.Directory({"tls": hashlib.sha256(b"test").hexdigest()}))
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.load_cert_chain(folder / "cert.pem", folder / "key.pem")
        service.socket = context.wrap_socket(service.socket, server_side=True, do_handshake_on_connect=False)
        worker = threading.Thread(target=service.serve_forever, daemon=True)
        worker.start()
        try:
            (folder / "project.godot").write_text('config_version=5\n[application]\nconfig/name="DiscoveryTLS"\nrun/main_scene="res://test.tscn"\n')
            (folder / "test.tscn").write_text('[gd_scene format=3]\n[ext_resource type="Script" path="res://test.gd" id="1"]\n[node name="Test" type="Node"]\nscript=ExtResource("1")\n')
            (folder / "classes.cfg").write_text('list=Array[Dictionary]([])\n')
            executable = folder / "FPSloppaServer.x86_64"
            shutil.copy2(args.server.resolve(), executable)
            manifest = {"output": str(executable.with_suffix(".pck")), "files": [
                {"path": "res://project.godot", "source": str(folder / "project.godot")},
                {"path": "res://test.gd", "source": str(ROOT / "deathmatch/tests/discovery_tls.gd")},
                {"path": "res://test.tscn", "source": str(folder / "test.tscn")},
                {"path": "res://.godot/global_script_class_cache.cfg", "source": str(folder / "classes.cfg")}]}
            (folder / "pack.json").write_text(json.dumps(manifest))
            subprocess.run([godot, "--headless", "--xr-mode", "off", "--path", str(ROOT),
                            "--log-file", str(logs / "packaging.log"), "--script", "res://deathmatch/server/package.gd",
                            "--", str(folder / "pack.json")], env=env, check=True, capture_output=True)
            result = subprocess.run([str(executable), "--log-file", str(logs / "engine.log"), "--",
                                     f"https://127.0.0.1:{service.server_port}", str(folder / "cert.pem")],
                                    cwd=folder, env=env, capture_output=True, text=True, timeout=20)
            output = result.stdout + result.stderr
            (logs / "runtime.log").write_text(output)
            report = next((json.loads(line.split("DISCOVERY_TLS_RESULT ", 1)[1]) for line in output.splitlines()
                           if line.startswith("DISCOVERY_TLS_RESULT ")), {})
            assert result.returncode == 0 and report and not report["failures"], output
            assert report["untrusted_result"] == 5 and report["hostname_result"] == 5, report
            (logs / "results.json").write_text(json.dumps(report, indent=2) + "\n")
            print("DISCOVERY_TLS_PASS", json.dumps(report))
        finally:
            service.shutdown(); service.server_close(); worker.join()


if __name__ == "__main__":
    main()
