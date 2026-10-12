"""Drive the installed OpenSCAD MCP over stdio; keep validation and export receipts."""
import asyncio,json,os
from pathlib import Path
from mcp import ClientSession,StdioServerParameters
from mcp.client.stdio import stdio_client
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/factory-optimization'
async def main():
 env={**os.environ,'OPENSCAD_PATH':'/usr/bin/openscad','MCP_RENDER_TIMEOUT':'300','MCP_ALLOWED_PATHS':str(ROOT),'MCP_TEMP_DIR':str(OUT/'mcp-temp')}
 command=os.environ.get('OPENSCAD_MCP_BIN',str(Path.home()/'.local/share/openscad-mcp-venv/bin/openscad-mcp'))
 async with stdio_client(StdioServerParameters(command=command,env=env)) as (read,write):
  async with ClientSession(read,write) as session:
   await session.initialize()
   records=[]
   for name,args in [('check_openscad',{}),('validate',{'scad_file':str(ROOT/'tools/voxelspace/assets/factory.scad'),'mode':'syntax'}),('export_model',{'scad_file':str(ROOT/'tools/voxelspace/assets/factory.scad'),'output_format':'csg','output_path':str(ROOT/'tools/voxelspace/assets/factory.csg')}),('export_model',{'scad_file':str(ROOT/'tools/voxelspace/assets/factory.scad'),'output_format':'off','output_path':str(OUT/'factory-union.off')})]:
    result=await session.call_tool(name,args)
    # SDK field names are snake_case in the installed MCP implementation.
    record=result.model_dump(mode='json',exclude_none=True)
    records.append({'tool':name,'arguments':args,'response':record})
    (OUT/'openscad-mcp.json').write_text(json.dumps(records,indent=2)+'\n')
    print(name,record.get('structured_content',record.get('structuredContent',{})),flush=True)
asyncio.run(main())
