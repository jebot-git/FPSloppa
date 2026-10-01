"""Build disposable instrumented resources, leaving production scripts untouched."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
EVENTS = 'res://tools/performance_suite/events.gd'
METRICS = 'res://deathmatch/avatars/animation_metrics.gd'


def wrap(source, name, args, event=None):
    pattern = r'^func '+re.escape(name)+r'\((.*)\) -> (\w+):$'
    match = re.search(pattern, source, re.M)
    if not match:
        raise ValueError(f'Instrumentation target changed: {name}')
    declaration, result = match[0], match[2]
    source = source[:match.start()] + declaration.replace('func '+name+'(', 'func suite_'+name+'(') + source[match.end():]
    source += '\n'+declaration+'\n'
    if event:
        source += f'\tpreload("{EVENTS}").record({event})\n'
    source += f'\tvar suite_start:=preload("{METRICS}").begin()\n'
    call = f'suite_{name}({args})'
    source += ('\t'+call if result == 'void' else f'\tvar suite_result: {result}='+call)+'\n'
    source += f'\tpreload("{METRICS}").end("{name}",suite_start)\n'
    if result != 'void':
        source += '\treturn suite_result\n'
    return source


def prepare(folder):
    folder.mkdir(parents=True, exist_ok=True)
    prefix = 'res://'+folder.relative_to(ROOT).as_posix()+'/'
    targets = {
        'deathmatch/arena.gd': [('_play_shot_fx', 'id,weapon,offhand,alternate,spray_direction',
            '"shot_fx",{"peer":id,"weapon":weapon,"rules":armory.effective(),"alternate":alternate,"offhand":offhand}')],
        'deathmatch/effects/combat.gd': [('hit','id,pos,direction,amount,dead,gibbed,seed_value',
            '"hit_fx",{"peer":id,"damage":amount,"dead":dead}'), ('_process','delta',None)],
        'deathmatch/experimental/visuals.gd': [('_process','delta',None),
            ('impacts','rules,start,ends,weapon,definition,muzzle_light',None),
            ('streak','points,color,width,life',None),
            ('_activate_shape','item,mesh,pos,color,life,start,end',None)],
        'deathmatch/audio/spatial.gd': [('choose','kind',None),('play','kind,where,volume',None)],
        'deathmatch/vr/tracking.gd': [('sample','',None)],
        'deathmatch/vr/rig.gd': [],
    }
    names = {path: path.removeprefix('deathmatch/').replace('/','_') for path in targets}
    for path, methods in targets.items():
        source = (ROOT/path).read_text()
        for name, args, event in methods:
            source = wrap(source, name, args, event)
        # Distinguish the two _process scopes.
        source = source.replace('end("_process",', f'end("{names[path]}._process",')
        for dependency, filename in names.items():
            source = source.replace('res://'+dependency, prefix+filename)
        (folder/names[path]).write_text(source)
    scene = (ROOT/'deathmatch/arena.tscn').read_text().replace('res://deathmatch/arena.gd',prefix+'arena.gd')
    (folder/'arena.tscn').write_text(scene)
    return prefix+'arena.tscn'
