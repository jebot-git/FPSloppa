"""Matching, original vector silhouettes for the seven deployed equipment types."""
from pathlib import Path
root=Path(__file__).resolve().parents[2]/'deathmatch/ui/weapon_icons'
shapes={
'remote_turret':'<path d="M67 91L74 141H86L93 91Z" fill="#596269"/><path d="M50 44L66 29H101L114 48V84H50Z" fill="#596269"/><path d="M72 61H134V74H72Z" fill="#ad834c"/><path d="M81 60V76M99 60V76M120 60V76"/><path d="M57 81H100V94H57Z" fill="#ad834c"/><circle cx="78" cy="48" r="6" fill="#68d5e6"/>',
'remote_inventory':'<path d="M66 83L74 140H86L94 83Z" fill="#596269"/><path d="M26 74H134V84H26Z" fill="#ad834c"/><path d="M20 39H32V108H20ZM128 39H140V108H128Z" fill="#596269"/><path d="M61 49H99L110 72L100 105H60L50 72Z" fill="#ad834c"/><path d="M65 66H96V81H65Z" fill="#68d5e6"/>',
'remote_ammo':'<path d="M65 99L73 141H87L95 99Z" fill="#596269"/><path d="M26 84H134V95H26Z" fill="#ad834c"/><path d="M20 48H32V113H20ZM128 48H140V113H128Z" fill="#596269"/><path d="M57 72H103L111 93L98 113H62L49 93Z" fill="#ad834c"/><path d="M63 87H72V100H63ZM77 87H86V100H77ZM91 87H100V100H91Z" fill="#68d5e6"/>',
'pulse_sensor':'<path d="M73 65H87V130H73Z" fill="#596269"/><path d="M63 128H97L102 145H58Z" fill="#ad834c"/>'+''.join(f'<circle cx="{x}" cy="{y}" r="20" fill="#ad834c"/><circle cx="{x}" cy="{y}" r="14" fill="#263540"/><circle cx="{x}" cy="{y}" r="5" fill="#68d5e6"/>' for x,y in [(43,69),(117,69),(80,32)]),
'motion_sensor':'<path d="M47 74L67 135H93L113 74L97 48H63Z" fill="#596269"/><path d="M54 53L70 34H92L106 53L92 64H69Z" fill="#ad834c"/><circle cx="66" cy="79" r="8" fill="#68d5e6"/><circle cx="94" cy="79" r="8" fill="#68d5e6"/>',
'remote_jammer':'<path d="M70 103L76 142H84L90 103Z" fill="#596269"/><path d="M80 19L93 58H67Z" fill="#ad834c"/><path d="M68 61H92L120 97L96 116H64L40 97Z" fill="#596269"/><path d="M67 65H93V74H67Z" fill="#68d5e6"/><path d="M50 94L73 107H88L110 94" fill="none" stroke="#ad834c"/>',
'remote_camera':'<path d="M60 92L74 140H86L100 92Z" fill="#596269"/><path d="M50 38L67 28H98L111 42V86L95 99H63L49 85Z" fill="#596269"/><circle cx="81" cy="66" r="24" fill="#ad834c"/><circle cx="81" cy="66" r="15" fill="#68d5e6"/>'}
for name,shape in shapes.items():
 (root/f'tribes_{name}.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="160" height="160" viewBox="0 0 160 160"><g stroke="#1b2931" stroke-width="4" stroke-linejoin="round">'+shape+'</g></svg>\n')
