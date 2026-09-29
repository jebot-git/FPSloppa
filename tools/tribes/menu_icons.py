"""Original ST menu pictograms; bronze/gunmetal equipment palette, no source art."""
from pathlib import Path
root = Path(__file__).resolve().parents[2] / 'deathmatch/tribes/menu_icons'
root.mkdir(exist_ok=True)
# All paths occupy the same square icon area, with large details readable in VR.
shapes = {
'weapons': '<path d="M26 40H104L131 54V68H87L65 83H48L43 112H24L33 68H26Z"/><path d="M87 75H132V91H111L102 120H85L92 91H68V81"/>',
'backpack': '<rect x="45" y="40" width="70" height="91" rx="10"/><path d="M61 40V26H99V40M45 58H32V118H45M115 58H128V118H115M57 88H103V116H57Z"/>',
'armour': '<path d="M55 29L67 42H93L105 29L137 48L127 76H112V131H48V76H33L23 48Z"/><path d="M62 63H98V96L80 109L62 96Z"/>',
'refit': '<path d="M42 52H118V126H42ZM63 52V35H97V52"/><path d="M61 91L75 106L101 75" stroke="#68d5e6" stroke-width="9"/>',
'carried': '<path d="M24 82Q80 113 136 82V110Q80 141 24 110Z"/><path d="M37 40H70V79H53L49 101H33L39 78H27V61H37ZM92 40H123V61H136V78H122L127 101H111L107 79H92Z"/>',
'field': '<path d="M26 55H134V130H26ZM56 55V34H104V55"/><path d="M62 73H98V83H89V114H71V83H62Z" fill="#68d5e6"/>',
'deployables': '<path d="M23 97H137L127 127H33ZM51 57H109V97H51Z"/><path d="M80 20V71M62 52L80 72L98 52" stroke="#68d5e6" stroke-width="8"/>',
'network': '<path d="M43 53L80 89L117 53M80 89V126" fill="none" stroke="#68d5e6" stroke-width="8"/><circle cx="43" cy="43" r="19"/><circle cx="117" cy="43" r="19"/><circle cx="80" cy="121" r="19"/>',
'kit': '<rect x="26" y="45" width="108" height="85" rx="9"/><path d="M59 45V28H101V45"/><path d="M69 62H91V78H108V100H91V117H69V100H52V78H69Z" fill="#68d5e6"/>',
'drop_pack': '<rect x="26" y="29" width="66" height="77" rx="9"/><path d="M42 29V19H75V29M38 64H80V91H38Z"/><path d="M119 46V114M99 97L119 119L139 97M98 135H140" stroke="#68d5e6" stroke-width="8"/>',
'share_ammo': '<path d="M29 63L38 40L47 63V106H29ZM56 63L65 40L74 63V106H56Z"/><path d="M89 52H138L123 37M138 52L123 67M136 99H87L102 84M87 99L102 114" fill="none" stroke="#68d5e6" stroke-width="7"/>',
'drop_weapon': '<path d="M22 37H95V51H64L51 66H43L39 91H21L29 61H22Z"/><path d="M119 45V112M99 94L119 116L139 94M90 133H140" stroke="#68d5e6" stroke-width="8"/>',
'beacon': '<path d="M69 65H91V122H69ZM46 122H114L121 136H39Z"/><path d="M57 33Q38 51 57 70M103 33Q122 51 103 70" fill="none" stroke="#68d5e6" stroke-width="7"/><circle cx="80" cy="51" r="12" fill="#68d5e6"/>',
'buy_beacons': '<path d="M39 57H61V111H39ZM25 111H75V127H25ZM89 75H111V121H89ZM78 121H124V137H78Z"/><path d="M103 23V57M86 40H120" stroke="#68d5e6" stroke-width="9"/>',
'close_camera': '<rect x="22" y="34" width="116" height="79" rx="8"/><path d="M80 113V132M53 132H107M60 55L100 92M100 55L60 92" stroke="#68d5e6" stroke-width="8"/>',
'release_turret': '<path d="M35 51H95V81H35ZM60 81V119M40 121H83M82 58H132V72H82Z"/><path d="M106 100L134 128M134 100L106 128" stroke="#68d5e6" stroke-width="8"/>',
'next': '<path d="M35 36L82 80L35 124M82 36L129 80L82 124" fill="none" stroke="#68d5e6" stroke-width="12"/>',
'back': '<path d="M82 35L34 78L82 119M37 78H103Q134 78 134 113" fill="none" stroke="#68d5e6" stroke-width="12"/>',
'contacts': '<circle cx="80" cy="80" r="55"/><path d="M80 26V80L115 108M28 80H132M80 80V134" fill="none"/><circle cx="53" cy="61" r="8" fill="#68d5e6"/><circle cx="107" cy="87" r="8" fill="#68d5e6"/>',
}
for kind in ['fusion','mini','elf','missile','mortar']:
    gun = {
        'fusion': '<path d="M70 51H141V65H70ZM70 72H141V86H70Z"/>',
        'mini': '<path d="M70 51H144V61H70ZM70 64H144V74H70ZM70 77H144V87H70Z"/>',
        'elf': '<path d="M73 47H139V59H94V78H139V90H73Z"/><path d="M114 58L105 71H124L115 81" stroke="#68d5e6"/>',
        'missile': '<path d="M77 43H142V92H77Z"/><circle cx="94" cy="58" r="7"/><circle cx="124" cy="58" r="7"/><circle cx="94" cy="78" r="7"/><circle cx="124" cy="78" r="7"/>',
        'mortar': '<path d="M65 74L112 22L136 45L89 95Z"/><path d="M108 26L130 48"/>',
    }[kind]
    shapes['turret_'+kind] = '<path d="M47 76H87L99 131H35ZM32 43H87V93H32Z"/>'+gun
for name, shape in shapes.items():
    (root / f'tribes_menu_{name}.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="160" height="160" viewBox="0 0 160 160"><g fill="#ad834c" stroke="#263540" stroke-width="5" stroke-linejoin="round" stroke-linecap="round">'+shape+'</g></svg>\n')
print(f'Generated {len(shapes)} ST menu icons')
