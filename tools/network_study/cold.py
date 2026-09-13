"""Cold TF map/model admission against the explicitly staged remote test server."""
import subprocess
from remote import ROOT, command

if __name__ == "__main__":
    assert command("match tf tf_vesper quake").get("ok")
    subprocess.run(["python3", str(ROOT/"tools/run_remote_probes.py"),
                    "--host", "45.147.228.101", "--port", "7777", "--count", "2",
                    "--hold", "5", "--label", "networkcoldfinal", "--cold"], check=True)
