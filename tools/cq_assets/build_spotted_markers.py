"""Original vector marker artwork, CC0; rebuild without external graphics packages."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'deathmatch/conquest/classes/icons/spotted';OUT.mkdir(exist_ok=True)
icons={
'shocktroop':'<path d="M35 12 20 35h12l-3 17 17-27H34z" fill="white" stroke="none"/>',
'scout':'<circle cx="32" cy="32" r="13"/><circle cx="32" cy="32" r="3" fill="white"/><path d="M32 14v7m0 22v7M14 32h7m22 0h7"/>',
'medic':'<path d="M27 16h10v11h11v10H37v11H27V37H16V27h11z" fill="white" stroke="none"/>',
'technician':'<path d="m28 15 8 0 2 7 7-2 4 7-5 5 5 5-4 7-7-2-2 7h-8l-2-7-7 2-4-7 5-5-5-5 4-7 7 2z"/><circle cx="32" cy="32" r="6"/>',
'light':'<path d="M17 35h30l4 10H13zM25 26h14l4 9H21zM33 26V15"/><circle cx="22" cy="41" r="2"/><circle cx="32" cy="41" r="2"/><circle cx="42" cy="41" r="2"/>',
'heavy':'<path d="M14 35h36l3 12H11zM23 25h18l4 10H19zM28 25V13m8 12V13M15 42h34"/>',
'rocket':'<path d="M14 38h36v9H14zM21 38V27h20v11M20 26l-4-9 28-7 4 9zM25 15l2 7m4-9 2 7m4-9 2 7"/><circle cx="23" cy="43" r="2"/><circle cx="41" cy="43" r="2"/>',
'transport':'<path d="M14 25h28l8 9v11H14zM20 25V15h23v10M39 30h6l4 6H39z"/><circle cx="23" cy="45" r="5" fill="#171b22"/><circle cx="43" cy="45" r="5" fill="#171b22"/>',
}
for name,art in icons.items():
 name=name.strip();svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><path d="M32 2 62 32 32 62 2 32Z" fill="#171b22" fill-opacity=".92" stroke="#ffad61" stroke-width="2.5"/><g stroke="white" stroke-width="3" stroke-linejoin="round" stroke-linecap="round" fill="none">{art}</g></svg>\n';(OUT/f'{name}.svg').write_text(svg)
(OUT/'LICENSE.txt').write_text('Original FPSloppa CQ spotted-marker artwork. CC0-1.0. https://creativecommons.org/publicdomain/zero/1.0/\n')
print('SPOTTED_MARKERS',len(icons))
