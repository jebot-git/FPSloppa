"""Author selected OGA sources through the installed Audacity MCP stdio server.
Run with Audacity 3.x + mod-script-pipe, and a Python env containing mcp.
Outputs are intermediate masters; build_field_audio.py performs runtime encoding.
"""
import asyncio,json
from pathlib import Path
from mcp import ClientSession,StdioServerParameters
from mcp.client.stdio import stdio_client
ROOT=Path(__file__).resolve().parents[2]
CACHE=ROOT/'tools/audio-sources/cq-field'
BLG=CACHE/'blacklodge/50-Free-SciFi-SFX-blacklodgegames.com'
JOBS=[('carbine',BLG/'blg_beam_01.wav',.0,.32,110,12500),('beam',BLG/'blg_beam_03.wav',.0,.75,80,14000),('assault',BLG/'blg_beam_02.wav',.0,.23,140,11000),('ordnance',CACHE/'scifi/rocket_01.ogg',0,1.4,60,10000),('jet_ignite',CACHE/'scifi/rocket_01.ogg',0,.38,100,8500),('repair',CACHE/'motor_loop.flac',0,1.8,120,6500)]
async def main():
 out=CACHE/'edited';out.mkdir(exist_ok=True);receipt=[]
 async with stdio_client(StdioServerParameters(command='/home/blux/.local/bin/audacity-mcp')) as (r,w):
  async with ClientSession(r,w) as session:
   await session.initialize()
   async def call(name,args={}):
    result=await session.call_tool(name,args)
    data=json.loads(result.content[0].text) if not result.isError else {'error':result.content[0].text}
    receipt.append({'tool':name,'arguments':args,'result':data})
    (out/'mcp-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    if result.isError or not data.get('success',False):raise RuntimeError(str(data))
    return data
   # Work in a new project, preserving any user's open project.
   await call('project_new')
   for name,path,start,end,high,low in JOBS:
    target=out/(name+'.wav')
    if target.exists():raise FileExistsError(target)
    await call('project_import_audio',{'path':str(path)})
    await call('select_all');await call('select_region',{'start':start,'end':end});await call('edit_trim')
    await call('select_all');await call('effect_high_pass_filter',{'frequency':high,'rolloff':'dB12'})
    await call('effect_low_pass_filter',{'frequency':low,'rolloff':'dB12'})
    await call('normalize',{'peak_level_db':-3,'remove_dc':True})
    await call('project_export_audio',{'path':str(target),'num_channels':1})
    await call('select_all');await call('track_remove')
   await call('project_close')
 print('AUDACITY_MCP_MASTERS_PASS',len(JOBS))
if __name__=='__main__':asyncio.run(main())
