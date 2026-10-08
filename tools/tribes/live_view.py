#!/usr/bin/env python3
"""Local browser view of the actual Godot spectator viewport and match telemetry."""
import argparse
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PAGE = b'''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>FPSloppa | Live ST match</title><style>
*{box-sizing:border-box}body{margin:0;background:#070c13;color:#e6eef7;font:16px system-ui}
header{padding:16px 24px;display:flex;justify-content:space-between;align-items:center}
strong{letter-spacing:.08em}#state{color:#6ce7c2}main{max-width:1440px;margin:auto}
img{display:block;width:100%;aspect-ratio:1.6;object-fit:contain;background:#020508}
footer{padding:16px 24px;color:#b6c8da;line-height:1.6}b{color:#fff}
</style><header><strong>FPSLOPPA / ST LIVE</strong><span id="state">Connecting to spectator...</span></header>
<main><img id="feed" alt="Live Godot spectator view of the 16 versus 16 ST match">
<footer id="stats">Waiting for match telemetry.</footer></main><script>
const feed=document.querySelector('#feed'),state=document.querySelector('#state');
function frame(){feed.src='/live.jpg?t='+Date.now()}
feed.onload=()=>{state.textContent='LIVE spectator feed';setTimeout(frame,200)};
feed.onerror=()=>{state.textContent='Waiting for spectator frame';setTimeout(frame,1000)};frame();
async function status(){try{let r=await fetch('/server.json',{cache:'no-store'});if(!r.ok)throw Error();
let s=await r.json(),a=s.vehicle_ai||{};
document.querySelector('#stats').textContent=`Scara Brae | ${s.teams[0]} vs ${s.teams[1]} bots | Red ${s.scores[0]} : ${s.scores[1]} Blue | ${Math.floor(s.seconds)}s elapsed | Vehicles purchased: ${a.purchases||0} | Boardings: ${a.boards||0} | Piloted distance: ${Math.round(a.distance||0)} m | Vehicle shots: ${a.shots||0}`;
}catch(e){}setTimeout(status,2000)}status();</script></html>'''

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--port', type=int, default=8787)
    args = parser.parse_args()
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            path = self.path.split('?', 1)[0]
            if path == '/':
                content, mime = PAGE, 'text/html; charset=utf-8'
            elif path in ('/live.jpg', '/server.json'):
                try:
                    resource = args.output / path[1:]
                    if path == '/live.jpg' and time.time() - resource.stat().st_mtime > 10:
                        self.send_error(503, 'Live spectator has stopped')
                        return
                    content = resource.read_bytes()
                except FileNotFoundError:
                    self.send_error(503, 'Spectator is starting')
                    return
                mime = 'image/jpeg' if path.endswith('.jpg') else 'application/json'
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header('Content-Type', mime)
            self.send_header('Content-Length', str(len(content)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            try:
                self.wfile.write(content)
            except (BrokenPipeError, ConnectionResetError):
                pass
        def log_message(self, *_args):
            pass
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    print(f'Live spectator: http://127.0.0.1:{args.port}', flush=True)
    server.serve_forever()

if __name__ == '__main__':
    main()
