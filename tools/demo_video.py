"""Render an FPSloppa demo with Godot Movie Maker and encode a shareable MP4.

Requires a graphical Vulkan/OpenGL session, Godot (or the client binary), ffmpeg.
Example: python3 tools/demo_video.py demos/match.fpsdemo --output video-output/match.mp4 --view chase --player 2
"""
from pathlib import Path
import argparse,shutil,subprocess,tempfile,os
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('demo',type=Path);p.add_argument('--output',type=Path,required=True)
 p.add_argument('--godot',default=os.environ.get('GODOT_BIN') or shutil.which('godot') or next(iter(sorted(str(x) for x in (Path.home()/'.local/bin').glob('Godot*linux*x86_64'))),'godot'))
 p.add_argument('--client',type=Path,help='Use an exported FPSloppa client instead of the source checkout')
 p.add_argument('--view',choices=['first','chase','free'],default='chase');p.add_argument('--player',type=int,default=0)
 p.add_argument('--fps',type=int,choices=[24,30,60],default=60);p.add_argument('--size',choices=['1280x720','1920x1080','2560x1440'],default='1920x1080')
 p.add_argument('--start',type=float,default=0);p.add_argument('--end',type=float);p.add_argument('--asset-root',type=Path)
 p.add_argument('--ffmpeg',default=shutil.which('ffmpeg'));p.add_argument('--dry-run',action='store_true');a=p.parse_args()
 if not a.demo.is_file():p.error('Demo file does not exist')
 if a.output.exists():p.error('Output already exists; choose another path')
 if a.start<0 or (a.end is not None and a.end<=a.start):p.error('Choose a nonnegative start and end after start')
 if not a.ffmpeg:p.error('Install ffmpeg to encode MP4')
 a.output.parent.mkdir(parents=True,exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='fpsloppa-video-',dir=a.output.parent) as tmp:
  movie=Path(tmp)/'capture.avi'
  cmd=[str(a.client.resolve())] if a.client else [a.godot,'--path',str(ROOT)]
  cmd+=['--xr-mode','off','--audio-driver','Dummy','--resolution',a.size,'--fixed-fps',str(a.fps),'--disable-vsync','--write-movie',str(movie.resolve()),'--','--demo',str(a.demo.resolve()),'--demo-view',a.view,'--demo-player',str(a.player),'--demo-start',str(a.start),'--demo-exit']
  if a.end is not None:cmd+=['--demo-end',str(a.end)]
  if a.asset_root:cmd+=['--asset-root',str(a.asset_root.resolve())]
  encode=[a.ffmpeg,'-nostdin','-n','-i',str(movie),'-vf',f'scale={a.size.replace("x",":")}:force_original_aspect_ratio=decrease,pad={a.size.replace("x",":")}:('+a.size.split('x')[0]+"-iw)/2:("+a.size.split('x')[1]+"-ih)/2",'-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-movflags','+faststart',str(a.output.resolve())]
  if a.dry_run:print('Render arguments:',cmd);print('Encode arguments:',encode);return
  subprocess.run(cmd,check=True)
  if not movie.is_file():raise RuntimeError('Godot did not produce a movie; inspect its demo/map diagnostics')
  subprocess.run(encode,check=True)
 print(a.output.resolve())
if __name__=='__main__':main()
