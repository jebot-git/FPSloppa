"""Generate an original, editable panel atlas; no pixels copied from references."""
from pathlib import Path
import random
root = Path(__file__).resolve().parents[2]
r = random.Random(3921)
svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">',
       '<defs><linearGradient id="shade" x2=".4" y2="1"><stop stop-color="#ffffff" stop-opacity=".20"/><stop offset=".45" stop-color="#000000" stop-opacity="0"/><stop offset="1" stop-color="#151b20" stop-opacity=".30"/></linearGradient></defs>']
# Rows: bronze, gunmetal, recess, neutral team panel. Columns: plain, seams,
# circular access panel, vents. Keeping small faces plain avoids stretched decals.
for row, (base, edge) in enumerate([((161,116,64),'#bcb3a0'),((92,97,99),'#a5aaa8'),((40,46,49),'#707a7c'),((172,174,165),'#c3c8c2')]):
    for col in range(4):
        svg.append(f'<g transform="translate({col*256} {row*256})"><rect width="256" height="256" fill="rgb{base}"/>')
        for i in range(1500):
            x,y=r.randrange(256),r.randrange(256)
            value=r.randrange(-27,28)
            rgb=tuple(max(0,min(255,c+value)) for c in base)
            svg.append(f'<path d="M{x} {y}h{r.randrange(1,5)}v{r.randrange(1,4)}h-3Z" fill="rgb{rgb}" opacity=".55"/>')
        svg.append('<rect width="256" height="256" fill="url(#shade)"/>')
        if col:
            svg.append(f'<path d="M10 42L42 10H214L246 42V214L214 246H42L10 214Z" fill="none" stroke="#343637" stroke-width="7"/><path d="M12 42L42 12H214L244 42V214L214 244H42L12 214Z" fill="none" stroke="{edge}" stroke-width="2"/>')
            for x,y in [(24,28),(232,28),(24,228),(232,228)]:
                svg.append(f'<circle cx="{x}" cy="{y}" r="3" fill="#252b2e" stroke="{edge}" stroke-width="1"/>')
        if col==1:
            svg.append(f'<path d="M20 212L91 178L164 77L237 42M20 40L65 65M191 191L236 216" fill="none" stroke="#343a3c" stroke-width="11"/><path d="M20 207L86 173L159 72L237 36M20 35L69 62M194 186L236 211" fill="none" stroke="{edge}" stroke-width="3"/>')
        elif col==2:
            svg.append(f'<circle cx="128" cy="128" r="51" fill="none" stroke="#444849" stroke-width="12"/><circle cx="128" cy="128" r="32" fill="#363b3e" stroke="{edge}" stroke-width="5"/><circle cx="128" cy="128" r="25" fill="rgb{tuple(int(c*.82) for c in base)}"/><path d="M20 64L63 100M193 154L236 192" stroke="{edge}" stroke-width="3"/>')
        elif col==3:
            svg.append('<path d="M64 56H192V200H64Z" fill="#242c30"/>')
            for y in range(63,198,12):
                svg.append(f'<path d="M67 {y}h122" stroke="{edge}" stroke-width="3"/>')
        svg.append('</g>')
svg.append('</svg>')
(root/'deathmatch/vehicles/tribes/hull-atlas.svg').write_text(''.join(svg))
