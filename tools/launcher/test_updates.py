"""Run transactional updater checks without touching a real installation."""
from pathlib import Path
import functools,http.server,os,shutil,subprocess,threading
ROOT=Path(__file__).resolve().parents[2]
LOG=ROOT/'test-results/launcher-update';LOG.mkdir(parents=True,exist_ok=True)
subprocess.run(['python3',str(Path(__file__).with_name('update_fixtures.py'))],cwd=ROOT,check=True)
fixture=Path('/tmp/fpsloppa-update-tests')
shutil.copy2(fixture/'http/.launcher-update/download.zip',fixture/'http/.launcher-update/source.zip')
class Server(http.server.ThreadingHTTPServer):allow_reuse_address=True
handler=functools.partial(http.server.SimpleHTTPRequestHandler,directory=str(fixture/'http/.launcher-update'))
with Server(('127.0.0.1',18954),handler) as server:
 threading.Thread(target=server.serve_forever,daemon=True).start()
 try:
  for script in ['launcher_updates','launcher_update_ui','launcher_update_http']:
   env=dict(os.environ,XDG_DATA_HOME=str(fixture/'userdata'),XDG_CONFIG_HOME=str(fixture/'config'),XDG_CACHE_HOME=str(fixture/'cache'))
   output=subprocess.run([os.environ.get('GODOT_BIN','godot'),'--headless','--xr-mode','off','--path',str(ROOT),'--script','deathmatch/tests/'+script+'.gd'],cwd=ROOT,env=env,capture_output=True,text=True,timeout=90)
   text=output.stdout+output.stderr;(LOG/(script+'.log')).write_text(text)
   if output.returncode or 'SCRIPT ERROR' in text or 'ERROR:' in text:raise RuntimeError(text)
   print(text.strip())
 finally:server.shutdown()
