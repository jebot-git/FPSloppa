#!/usr/bin/env python3
"""Loopback-only live camera viewer. Serves only the scenario's frame/report files."""
import argparse
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HTML = '''<!doctype html><meta charset="utf-8"><title>Valley Junction · Live</title>
<style>body{background:#10191c;color:#e6efe9;font:16px system-ui;margin:24px}main{max-width:1200px;margin:auto}img{width:100%;border-radius:8px;background:#22312c;min-height:300px}button{background:#354e43;color:white;border:0;border-radius:6px;padding:12px;margin:4px;cursor:pointer}pre{white-space:pre-wrap}a{color:#a6dbbd}</style>
<main><h2>Valley Junction · 16v16 live view</h2><p>Live game frames update every two seconds. Select a camera:</p>
<nav><button onclick="camera(-1)">Overview</button><button onclick="camera(0)">Town</button><button onclick="camera(1)">Factory</button><button onclick="camera(2)">Port</button><button onclick="camera(3)">Military</button><button onclick="camera(4)">Radar</button></nav>
<img id="feed" alt="Waiting for the game renderer"><pre id="stats">Preparing terrain, navigation and VRMs…</pre><a href="match.json">Match report</a> · <a href="performance.json">Performance report</a></main>
<script>async function camera(site){await fetch('/camera',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({site})})}async function refresh(){try{let r=await fetch('/live.json?t='+Date.now());if(r.ok){let s=await r.json();document.querySelector('#stats').textContent=JSON.stringify(s,null,2);document.querySelector('#feed').src='/live.jpg?t='+Date.now()}}catch(e){document.querySelector('#stats').textContent='Waiting for the local game…'}}setInterval(refresh,2000);refresh();</script>'''

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--directory', type=Path, required=True)
    parser.add_argument('--port', type=int, default=8766)
    args = parser.parse_args()
    directory = args.directory.resolve()
    directory.mkdir(parents=True, exist_ok=True)

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            name = self.path.split('?', 1)[0].lstrip('/')
            if not name:
                body, mime = HTML.encode(), 'text/html; charset=utf-8'
            elif name in ('live.jpg', 'live.json', 'match.json', 'performance.json'):
                path = directory / name
                if not path.exists():
                    self.send_error(404)
                    return
                body = path.read_bytes()
                mime = 'image/jpeg' if name.endswith('.jpg') else 'application/json'
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header('Content-Type', mime)
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            if self.path != '/camera' or self.headers.get('Content-Type') != 'application/json':
                self.send_error(400)
                return
            length = int(self.headers.get('Content-Length', 0))
            if not 0 < length <= 128:
                self.send_error(400)
                return
            try:
                site = json.loads(self.rfile.read(length))['site']
                if type(site) is not int or not -1 <= site <= 4:
                    raise ValueError('Invalid camera')
            except (ValueError, KeyError):
                self.send_error(400)
                return
            path = directory / 'camera.tmp'
            path.write_text(json.dumps({'site': site, 'sequence': time.time_ns()}))
            path.replace(directory / 'camera.json')
            self.send_response(204)
            self.end_headers()

        def log_message(self, *_):
            pass

    print(f'LIVE_VIEW http://127.0.0.1:{args.port}', flush=True)
    ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()

if __name__ == '__main__':
    main()
