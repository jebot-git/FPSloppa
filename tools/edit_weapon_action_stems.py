"""Edit recorded sources through the installed Audacity MCP; preserve other projects."""
import asyncio,json
from pathlib import Path
from mcp import ClientSession,StdioServerParameters
from mcp.client.stdio import stdio_client
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'tools/audio-sources/weapon-actions/edited';OUT.mkdir(parents=True,exist_ok=True)
LOG=ROOT/'test-results/weapon-actions-20261001/audacity-edits.json';log=[]
SPECS=[('motor','tools/audio-sources/ambience/factory-edited.wav',90,4200),('liquid','tools/audio-sources/natural-weapons/bubbles.wav',90,3800),('pressure','tools/audio-sources/ambience/wind.wav',200,6200),('mechanism','tools/audio-sources/natural-weapons/rifle-reload.wav',120,8500),('saw_idle','tools/audio-sources/weapon-actions/dssawidl.wav',60,6500),('saw_ready','tools/audio-sources/weapon-actions/dssawup.wav',60,6500)]
async def main():
 async with stdio_client(StdioServerParameters(command='/home/blux/.local/bin/audacity-mcp')) as (reader,writer):
  async with ClientSession(reader,writer) as s:
   await s.initialize()
   async def call(name,args):
    r=await s.call_tool(name,args);log.append({'tool':name,'args':args,'result':r.model_dump()});LOG.write_text(json.dumps(log,indent=2))
    if r.isError:raise RuntimeError(r.model_dump_json())
    for c in r.content:
     if c.type=='text':
      try:
       if json.loads(c.text).get('success') is False:raise RuntimeError(c.text)
      except json.JSONDecodeError:pass
   for name,path,low,high in SPECS:
    await call('project_new',{});await call('project_import_audio',{'path':str(ROOT/path)});await call('select_all',{})
    await call('effect_high_pass_filter',{'frequency':low,'rolloff':'dB12'});await call('effect_low_pass_filter',{'frequency':high,'rolloff':'dB12'})
    await call('normalize',{'peak_level_db':-6,'remove_dc':True,'stereo_independent':False})
    await call('project_export_audio',{'path':str(OUT/(name+'.wav')),'num_channels':1})
    print('EDITED',name,flush=True)
asyncio.run(asyncio.wait_for(main(),240))
