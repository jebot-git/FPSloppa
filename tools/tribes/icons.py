from pathlib import Path
import re
p=Path('deathmatch/ui/weapon_icons')
shapes={
'blaster':'M20 45H72L88 54H123V72H82L72 83H51L45 108H27L32 77H20Z M87 46H144V57H87Z M88 64H144V75H88Z',
'plasma':'M19 44H61L78 37H134L150 54V77L134 93H62L49 106H30L35 78H19Z M70 48V81 M88 48V81 M105 48V81',
'chaingun':'M19 50H61V87H19Z M63 42H84V92H63Z M84 46H151V55H84Z M84 64H155V73H84Z M84 82H151V91H84Z M31 85L28 112H46L55 87Z',
'disc':'M22 64H73V83H54L47 109H29L34 83H22Z M66 67A40 27 0 1 1 146 67A40 27 0 1 1 66 67 M70 65H148V72H70Z',
'grenade_launcher':'M21 53H69V82H53L46 110H28L34 83H21Z M61 43H147V74H61Z M91 47V70 M111 47V70 M130 47V70 M65 82A22 22 0 1 1 109 82A22 22 0 1 1 65 82',
'laser':'M15 61H91V77H53L43 102H29L35 76H15Z M91 64H158V70H91Z M50 37H105V51H50Z M61 51V61 M94 51V61',
'elf':'M21 51H67V83H53L45 108H28L34 82H21Z M63 45H88V90H63Z M88 44H150V57H88Z M88 76H150V89H88Z M98 57L119 67L98 76',
'mortar':'M18 55H45V87H34L29 111H47L56 86H137V35H48V55Z M125 35H150V87H125Z M58 36V87 M85 36V87',
'repair':'M19 53H76V81H51L43 110H26L33 81H19Z M75 44H98V88H75Z M98 47H147V60H98Z M98 75H147V88H98Z M43 38V61 M33 49H54',
'grenade':'M57 36H112V102L101 111H68L57 102Z M69 25H100V37H69Z M62 57H108 M62 81H108',
'mine':'M23 88L42 62H131L153 88L137 104H40Z M63 62V51H109V62 M30 87H147 M77 71H99V80H77Z',
 'targeter':'M23 54H89V81H54L46 108H28L34 81H23Z M89 60H131V72H89Z M138 45V86 M128 65H154',
}
for name,path in shapes.items():(p/('tribes_'+name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="176" height="128" viewBox="0 0 176 128"><path d="{path}" fill="none" stroke="#ffffff" stroke-width="5" stroke-linejoin="round"/></svg>')
for i,name in enumerate(['light','medium','heavy']):
 width=25+i*7;path=f'M{88-width} 35H{88+width}L{130+i*8} 50V74H{88+width}V111H{88-width}V74H{46-i*8}V50Z'
 (p/('tribes_'+name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="176" height="128"><path d="{path}" fill="none" stroke="white" stroke-width="5"/><path d="M71 47H105" stroke="white" stroke-width="8"/></svg>')
for name,mark in [('energy','M82 44L66 72H89L80 95L111 64H89L99 44Z'),('ammo','M63 55H113 M63 72H113 M63 89H113'),('repair','M88 49V96 M66 73H110'),('shield','M63 49H113V77L88 102L63 77Z'),('jammer','M65 33V16 M109 33V16 M67 69Q88 40 110 69 M75 80Q88 64 101 80')]:
 (p/('tribes_'+name+'_pack.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="176" height="128"><rect x="48" y="35" width="80" height="80" rx="10" fill="none" stroke="white" stroke-width="5"/><path d="{mark}" fill="none" stroke="white" stroke-width="5"/></svg>')
q=Path('deathmatch/ui/weapon_icons.gd');s=q.read_text();names=['BLASTER','PLASMA GUN','CHAINGUN','DISC LAUNCHER','GRENADE LAUNCHER','LASER RIFLE','ELF GUN','MORTAR','REPAIR GUN','HAND GRENADE','LAND MINE','TARGETING LASER'];entries={}
for title,key in zip(names,shapes):entries['TRIBES '+title]='tribes_'+key
for title,key in zip(names,shapes):
 if title not in ['CHAINGUN','GRENADE LAUNCHER']:entries[title]='tribes_'+key
for name in ['light','medium','heavy']:entries[name.upper()+' ARMOUR']='tribes_'+name
for name in ['energy','ammo','repair','shield','jammer']:entries['SENSOR JAMMER' if name=='jammer' else name.upper()+' PACK']='tribes_'+name+'_pack'
for key in entries:s=re.sub(r'"'+re.escape(key)+r'"\s*:\s*"[^"]*",?', '', s)
s=s.replace('const NAMES={','const NAMES={'+','.join('"'+k+'":"'+v+'"' for k,v in entries.items())+',');q.write_text(s)
q=Path('deathmatch/vr/weapon_wheel.gd');s=q.read_text().replace('"name":data.name,"ammo":ammo','"name":data.name,"icon":("TRIBES "+data.name) if game.match_mode.tribes.enabled() else data.name,"ammo":ammo');q.write_text(s)
q=Path('deathmatch/tribes/buy_wheel.gd');s=q.read_text().replace('"icon":A.NAMES[w]','"icon":"TRIBES "+A.NAMES[w]');q.write_text(s)
