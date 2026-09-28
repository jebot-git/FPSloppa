"""Original Tribes-inspired field metal atlas, painted through the live Krita MCP."""
from pathlib import Path
import importlib.util,subprocess,json,random
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'tools/tribes/refined'
from PIL import Image,ImageDraw
COLORS=['#536461','#273137','#927d50','#9fa9a6','#161d22','#37b9d3','#dea844','#ab4437']
im=Image.new('RGB',(1024,512));draw=ImageDraw.Draw(im);r=random.Random(1998)
for i,c in enumerate(COLORS):
 x=i%4*256;y=i//4*256;draw.rectangle((x,y,x+255,y+255),fill=c)
 for j in range(800):
  px=x+r.randrange(16,240);py=y+r.randrange(16,240);base=tuple(int(c[k:k+2],16) for k in (1,3,5));v=r.randint(-5,5);draw.point((px,py),fill=tuple(max(0,min(255,b+v)) for b in base))
im.save(OUT/'finish-base.png')
with subprocess.Popen(['python3',str(Path.home()/'.local/share/krita-mcp/mcp_server.py')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True) as server:
 seq=0
 def rpc(method,params):
  global seq
  seq+=1;server.stdin.write(json.dumps(dict(jsonrpc='2.0',id=seq,method=method,params=params))+'\n');server.stdin.flush();res=json.loads(server.stdout.readline());assert 'error' not in res,res
  result=res['result'];assert not result.get('isError'),result;return result
 def call(tool_name,**args):
  result=rpc('tools/call',dict(name=tool_name,arguments=args));print(tool_name, 'OK');return result
 rpc('initialize',dict(protocolVersion='2025-06-18',capabilities={},clientInfo=dict(name='tribes-art',version='1')))
 server.stdin.write(json.dumps(dict(jsonrpc='2.0',method='notifications/initialized'))+'\n');server.stdin.flush()
 call('status');call('open_document',path=str(OUT/'finish-base.png'));call('set_layer',new_name='Field metal base',locked=True)
 call('create_layer',name='Machining and edge scuffs',opacity=.30)
 commands=[]
 for i in range(8):
  x=i%4*256;y=i//4*256
  for j in range(70):
   px=x+r.uniform(18,225);py=y+r.uniform(18,238)
   commands.append(dict(type='line',x1=px,y1=py,x2=min(x+240,px+r.uniform(2,18)),y2=py+r.uniform(-.7,.7),stroke_width=r.uniform(.4,1.1),color='#d4d6c5'))
 call('draw',commands=commands)
 call('create_layer',name='Recesses and service panel seams',opacity=.50)
 commands=[]
 for i in [0,1,2,3]:
  x=i%4*256;y=0
  for off in [30,220]:commands.append(dict(type='line',x1=x+20,y1=y+off,x2=x+236,y2=y+off,stroke_width=2,color='#10191c'))
 call('draw',commands=commands)
 call('save_document',path=str(OUT/'finish.kra'));call('export_document',path=str(OUT/'finish.png'));call('inspect_document');server.stdin.close();server.wait(timeout=10)
