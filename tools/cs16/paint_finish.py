"""Add subtle wear layers in Krita through its MCP stdio server.

Run after the Blender base-atlas build. The editable KRA and flattened export
are authoring sources; Blender prefers that export on subsequent builds.
Requires the Krita MCP bridge (https://github.com/SanSaSane/krita-mcp).
"""
import argparse
import base64
import json
from pathlib import Path
import random
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tools/cs16/refined"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", type=Path, default=Path.home() / ".local/share/krita-mcp/mcp_server.py")
    args = parser.parse_args()
    with subprocess.Popen(["python3", str(args.server)], stdin=subprocess.PIPE,
                          stdout=subprocess.PIPE, text=True) as server:
        seq = 0

        def rpc(method, params):
            nonlocal seq
            seq += 1
            server.stdin.write(json.dumps(dict(jsonrpc="2.0", id=seq, method=method, params=params)) + "\n")
            server.stdin.flush()
            response = json.loads(server.stdout.readline())
            assert "error" not in response, response
            result = response["result"]
            assert not result.get("isError"), result
            return result

        def call(tool_name, **arguments):
            result = rpc("tools/call", dict(name=tool_name, arguments=arguments))
            for item in result.get("content", []):
                if item["type"] == "text":
                    print(tool_name, item["text"])
                elif item["type"] == "image":
                    (ROOT / "test-results/cs16/art-refine/krita-atlas.png").write_bytes(base64.b64decode(item["data"]))
            return result

        rpc("initialize", dict(protocolVersion="2025-06-18", capabilities={}, clientInfo=dict(name="fpsloppa-art", version="1")))
        server.stdin.write(json.dumps(dict(jsonrpc="2.0", method="notifications/initialized")) + "\n")
        server.stdin.flush()
        call("status")
        call("open_document", path=str(OUT / "cs16-finish.png"))
        call("set_layer", new_name="Base materials — Blender source", locked=True)
        rng = random.Random(160927)
        call("create_layer", name="Brushed wear and rubbed edges", opacity=.35)
        commands = []
        # PNG coordinates run top to bottom; the UV atlas origin is bottom left.
        for tile in [0, 4, 5]:
            ox, oy = tile % 4 * 256, (1 - tile // 4) * 256
            for _ in range(40):
                x = ox + rng.uniform(22, 215)
                y = oy + rng.uniform(24, 232)
                commands.append(dict(type="line", x1=x, y1=y, x2=min(ox + 233, x + rng.uniform(3, 23)),
                                     y2=y + rng.uniform(-.6, .6), stroke_width=rng.uniform(.5, 1.2),
                                     color="#b1bdc9" if tile == 0 else "#ece5ce", cap="round"))
            for _ in range(15):
                x = ox + rng.uniform(23, 216)
                y = oy + rng.choice([15.5, 239.5])
                commands.append(dict(type="line", x1=x, y1=y, x2=x + rng.uniform(2, 15),
                                     y2=y + rng.uniform(-1, 1), stroke_width=1.4, color="#ccd0ce"))
        call("draw", commands=commands)
        call("create_layer", name="Furniture handling marks", opacity=.15)
        commands = []
        for tile, color in [(1, "#979185"), (2, "#e6ac65"), (3, "#b8b395"), (7, "#d3b176")]:
            ox, oy = tile % 4 * 256, (1 - tile // 4) * 256
            for _ in range(22):
                x, y = ox + rng.uniform(25, 205), oy + rng.uniform(27, 230)
                commands.append(dict(type="line", x1=x, y1=y, x2=x + rng.uniform(6, 29),
                                     y2=y + rng.uniform(-1.5, 1.5), stroke_width=rng.uniform(.7, 1.6), color=color))
        call("draw", commands=commands)
        call("save_document", path=str(OUT / "cs16-finish.kra"))
        call("export_document", path=str(OUT / "cs16-finish-painted.png"))
        call("inspect_document")
        call("get_image", max_size=1024)
        server.stdin.close()
        server.wait(timeout=10)


if __name__ == "__main__":
    main()
