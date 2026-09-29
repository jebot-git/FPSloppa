"""Generate disposable instrumented copies; never edit production gameplay code."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test-results/native-study'
OUT.mkdir(parents=True, exist_ok=True)
PREFIX = 'res://test-results/native-study/'

def instrument(source, names):
    source += '\nstatic var native_audit: Dictionary={}\n'
    for name, args in names.items():
        match = re.search(r'^(static )?func '+name+r'\((.*)\) -> (\w+):$', source, re.M)
        assert match, name
        declaration = match.group(0)
        static = match.group(1) or ''
        result = match.group(3)
        source = source[:match.start()] + declaration.replace('func '+name+'(', 'func audit_original_'+name+'(') + source[match.end():]
        source += '\n'+declaration+'\n\tvar audit_start:=Time.get_ticks_usec()\n'
        call = f'audit_original_{name}({args})'
        source += ('\t'+call if result == 'void' else '\tvar audit_result: '+result+'='+call)+'\n'
        source += '\tvar audit_elapsed:=Time.get_ticks_usec()-audit_start\n'
        source += f'\tif not native_audit.has("{name}"):native_audit["{name}"]=[0,0]\n'
        source += f'\tnative_audit["{name}"][0]+=audit_elapsed;native_audit["{name}"][1]+=1\n'
        if result != 'void': source += '\treturn audit_result\n'
    return source

def read(path): return (ROOT/path).read_text()
def write(name, text): (OUT/name).write_text(text)

write('hits.gd', instrument(read('deathmatch/hit_detection.gd'), {
    'world_fraction':'space,start,end,radius', 'player_fraction':'start,end,height,yaw,radius',
    'player_axis':'impact,height,yaw', 'player_head':'point,height,yaw,radius'}))
write('targets.gd', instrument(read('deathmatch/projectile_targets.gd'), {
    'build':'players,fighters,movement_start','candidates':'start,end,radius'}))
write('codec.gd', instrument(read('deathmatch/network/codec.gd'), {'encode':'value','decode':'raw'}))
write('snapshot_codec.gd', instrument(read('deathmatch/network/snapshot_codec.gd').replace('res://deathmatch/network/codec.gd', PREFIX+'codec.gd'), {'pack':'value','encode':'value'}))
write('replication.gd', instrument(read('deathmatch/network/replication.gd').replace('res://deathmatch/network/snapshot_codec.gd',PREFIX+'snapshot_codec.gd'), {'packets':'snapshot'}))
arena = read('deathmatch/arena.gd')
for old,new in [('hit_detection','hits'),('projectile_targets','targets'),('network/replication','replication')]:
    arena=arena.replace('res://deathmatch/'+old+'.gd', PREFIX+new+'.gd')
# Exercise real packet construction even though this fixture has no remote peers.
arena=arena.replace('if not multiplayer.get_peers().is_empty():\n\t\tvar packets:', 'if OS.get_cmdline_user_args().has("--packets") or not multiplayer.get_peers().is_empty():\n\t\tvar packets:')
write('arena.gd',instrument(arena, {'_trace':'start,end,exclude,rewind,radius,movement_start,candidates'}))
write('profiled_arena.gd',read('deathmatch/tests/profiled_arena.gd').replace('res://deathmatch/arena.gd',PREFIX+'arena.gd'))
fixture=read('deathmatch/tests/server_load_audit.gd').replace('res://deathmatch/tests/profiled_arena.gd',PREFIX+'profiled_arena.gd')
fixture=fixture.replace('func run():','func run():\n\tseed(20260928)')
report='\tfor label in ["hits","targets","codec","snapshot_codec","replication","arena"]:\n\t\tprint("NATIVE_SCOPE ",JSON.stringify({"scope":label,"ticks_including_warmup":duration,"samples":load("'+PREFIX+'"+label+".gd").native_audit}))\n'
fixture=fixture.replace('\tg.disconnect_game();',report+'\tg.disconnect_game();')
write('server.gd',fixture)
print(OUT)
