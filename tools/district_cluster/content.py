"""Private master HTTP service: static campaign page and bounded VRM-only storage.

Expose through a TLS proxy, or access over the playtest WireGuard network.
Only this validated path may change a player's content-addressed avatar hash.
"""
import hashlib
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import re
import subprocess
import tempfile
import threading
import time

MAX_BYTES=25_000_000


def server(address, store, root, binary, status_file, budget=5_000_000_000):
    root=Path(root);root.mkdir(parents=True,exist_ok=True)
    upload_lock=threading.BoundedSemaphore(1)
    download_lock=threading.Lock()
    next_download=[0.]
    def pace(size):
        with download_lock:
            now=time.monotonic();at=max(now,next_download[0]);next_download[0]=at+size/8_000_000
        if at>now:time.sleep(at-now)
    class Handler(BaseHTTPRequestHandler):
        def setup(self):
            super().setup();self.connection.settimeout(30)
        def log_message(self, *_args):pass # Never log authentication headers.
        def auth(self):
            return dict(actor=self.headers.get('X-CQ-ID',''),resume=self.headers.get('X-CQ-Secret',''))
        def result(self,code,data,kind='application/json'):
            if not isinstance(data,bytes):data=json.dumps(data).encode()
            self.send_response(code);self.send_header('Content-Type',kind);self.send_header('Content-Length',str(len(data)))
            self.send_header('X-Content-Type-Options','nosniff');self.end_headers();self.wfile.write(data)
        def do_GET(self):
            if self.path in ('/','/index.html'):
                try:self.result(200,Path(status_file).read_bytes(),'text/html; charset=utf-8')
                except FileNotFoundError:self.result(503,{'error':'Campaign status not ready'})
                return
            match=re.fullmatch(r'/vrm/([0-9a-f]{64})\.vrm',self.path)
            if not match:self.result(404,{'error':'Not found'});return
            path=root/(match[1]+'.vrm')
            try:
                with path.open('rb') as file:
                    self.send_response(200);self.send_header('Content-Type','application/octet-stream')
                    self.send_header('Content-Length',str(path.stat().st_size));self.send_header('Cache-Control','public, max-age=31536000, immutable');self.end_headers()
                    while data:=file.read(65536):pace(len(data));self.wfile.write(data)
            except FileNotFoundError:self.result(404,{'error':'VRM not found'})
        def do_POST(self):
            if self.path!='/vrm':self.result(404,{'error':'Only VRM content is accepted'});return
            if self.headers.get('Transfer-Encoding') or self.headers.get('Content-Type')!='application/octet-stream':
                self.result(415,{'error':'Use a length-delimited binary VRM'});return
            try:
                size=int(self.headers.get('Content-Length','0'))
                if not 28<=size<=MAX_BYTES:raise ValueError('VRM must be at most 25 MB')
                store.execute(dict(op='profile',**self.auth()),None)
            except (ValueError,KeyError):self.result(403,{'error':'Invalid session or VRM size'});return
            if not upload_lock.acquire(blocking=False):self.result(429,{'error':'VRM validation busy; retry shortly'});return
            temporary=None
            try:
                if sum(p.stat().st_size for p in root.glob('*.vrm'))+size>budget:
                    self.result(507,{'error':'VRM storage budget reached'});return
                with tempfile.NamedTemporaryFile(dir=root,suffix='.upload',delete=False) as file:
                    temporary=Path(file.name);remaining=size;digest=hashlib.sha256()
                    while remaining:
                        chunk=self.rfile.read(min(65536,remaining))
                        if not chunk:raise ValueError('Incomplete upload')
                        file.write(chunk);digest.update(chunk);remaining-=len(chunk)
                result=subprocess.run([str(Path(binary).resolve()),'--','--cq-service','vrm','--file',str(temporary.resolve())],
                    capture_output=True,timeout=20,cwd=root)
                if result.returncode or b'VRM_ACCEPT' not in result.stdout:raise ValueError('Invalid or unsupported VRM')
                sha=digest.hexdigest();target=root/(sha+'.vrm')
                temporary.replace(target);temporary=None
                store.execute(dict(op='set_avatar',avatar=sha,**self.auth()),None)
                self.result(200,dict(hash=sha,size=size))
            except (ValueError,OSError,subprocess.TimeoutExpired):
                self.result(400,{'error':'VRM upload or validation failed'})
            finally:
                if temporary:temporary.unlink(missing_ok=True)
                upload_lock.release()
    class HTTP(ThreadingHTTPServer):
        daemon_threads=True
        def __init__(self,*args):
            self.slots=threading.BoundedSemaphore(24)
            super().__init__(*args)
        def process_request(self, request, address):
            if not self.slots.acquire(False):request.close();return
            try:super().process_request(request,address)
            except BaseException:self.slots.release();raise
        def process_request_thread(self, request, address):
            try:super().process_request_thread(request,address)
            finally:self.slots.release()
    return HTTP(tuple(address),Handler)
