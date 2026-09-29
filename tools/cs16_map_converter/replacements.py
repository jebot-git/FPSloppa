"""Original deterministic indexed industrial materials; no third-party assets.

An explicit fallback, not a reconstruction of the missing WAD art. Semantic
classification is inspectable and overridable; dimensions and UVs stay intact.
"""
import hashlib
import re
from bsp import require

COLOURS = {
    'concrete': ((143,145,139),(94,100,99),(166,148,116),(57,62,59)),
    'metal': ((111,126,131),(59,72,78),(158,155,132),(74,55,43)),
    'panel': ((132,149,151),(59,77,82),(153,156,130),(68,78,83)),
    'tile': ((166,175,168),(63,76,78),(150,146,125),(51,60,63)),
    'brick': ((137,103,83),(99,97,90),(147,126,97),(55,56,54)),
    'rock': ((124,115,95),(85,86,76),(148,141,118),(52,54,47)),
    'wood': ((141,108,69),(65,64,56),(166,139,93),(58,53,43)),
    'door': ((114,134,136),(49,66,72),(163,151,108),(43,52,57)),
    'screen': ((76,96,99),(37,63,62),(111,195,156),(192,159,80)),
    'light': ((203,211,198),(66,81,87),(232,216,163),(104,114,111)),
    'glass': ((78,112,126),(53,76,90),(128,157,167),(47,63,68)),
    'grate': ((133,142,142),(57,69,76),(141,126,103),(47,56,64)),
    'hazard': ((202,165,65),(37,43,42),(156,127,55),(64,65,57)),
    'sign': ((64,105,87),(41,59,55),(205,211,191),(155,128,75)),
    'black': ((6,7,8),(5,6,7),(8,9,10),(4,5,6)),
    'sky': ((126,150,166),(77,100,120),(183,183,163),(47,63,83)),
    'utility': ((120,120,120),)*4,
}


def category(name):
    n = re.sub(r'^[+-][0-9a-z]', '', name.lower())
    if n in ('aaatrigger', 'clip', 'null', 'hint', 'origin'): return 'utility'
    if n.startswith('sky'): return 'sky'
    if n == 'black': return 'black'
    if n.startswith('{') or any(s in n for s in ('grate','ladder','rail','razor','vent','intk')): return 'grate'
    if any(s in n for s in ('comp','cmpm','crt','gdpnl','gad')): return 'screen'
    if any(s in n for s in ('light','lght','lgt','spot','_lt')): return 'light'
    if 'glass' in n or 'labglu' in n: return 'glass'
    if 'stripe' in n or 'hazard' in n: return 'hazard'
    if 'sign' in n or 'exit' in n: return 'sign'
    if 'crate' in n or 'wood' in n or n.endswith('wd'): return 'wood'
    if 'door' in n or re.search(r'(^|_)dr|secdr',n): return 'door'
    if any(s in n for s in ('tile','flr','floor','lino','pav','trd','stp')): return 'tile'
    if 'rock' in n or 'out_rk' in n: return 'rock'
    if 'brick' in n: return 'brick'
    if any(s in n for s in ('trim','brd','post','brdly','lift','gar','tnnl','tech')): return 'metal'
    if 'crete' in n or 'wall' in n or re.search(r'_w[0-9]',n): return 'concrete'
    return 'panel'


def generate(name, width, height, kind=None):
    kind = kind or category(name)
    require(kind in COLOURS, 'Unknown replacement category: '+str(kind))
    # Animated variants share a seed so a static replacement is consistent.
    canonical = re.sub(r'^[+-][0-9a-z]', '', name)
    seed = int.from_bytes(hashlib.sha256(canonical.encode()).digest()[:4], 'little')
    palette = bytes(max(0,min(255,round(c*(.25+.9*j/63)))) for bank in COLOURS[kind] for j in range(64) for c in bank)
    palette = palette[:765]+bytes((0,0,255))
    masked = name.startswith('{')
    pixels = bytearray()
    for y in range(height):
        for x in range(width):
            noise = ((x*374761393+y*668265263+seed)&0xffffffff)
            noise = ((noise^(noise>>13))*1274126177)&0xffffffff
            shade = 45+((noise>>17)%9)-4; bank = 0
            u=x/width;v=y/height
            edge=min(x,y,width-1-x,height-1-y)
            if kind in ('panel','metal','door'):
                if edge<2: bank=1;shade=25
                elif edge<4:shade=59
                if (x%32 in (3,4) and y%32 in (3,4)):bank=1;shade=18
                if kind=='metal' and y%16<2:shade-=9
                if kind=='door' and (abs(u-.5)<.014 or .12<u<.88 and .35<v<.37):bank=1;shade=20
                if kind=='door' and .73<u<.85 and .49<v<.56:bank=2;shade=55
            elif kind in ('tile','brick'):
                tx=(x+(16 if kind=='brick' and y//16%2 else 0))%(32 if kind=='brick' else 24)
                ty=y%(16 if kind=='brick' else 24)
                if tx<2 or ty<2:bank=1;shade=27
                elif tx==2 or ty==2:shade=58
            elif kind=='concrete':
                shade+=int(((x//7*3+y//9*5+seed)%13)-6)
                if y%128<2:bank=1;shade=32
                if (x+seed%17)%64<2 and y%128<5:bank=3
            elif kind=='rock':
                shade+=((x//9+y//11*3+seed)%17)-8
                if (x//3+y//5+seed)%23==0:shade-=10
            elif kind=='wood':
                shade+=(y*7+x//13+seed)%11-5
                if y%16<2:shade-=16
                if edge<5 or abs(u-v)<.035:bank=1;shade=35
                if edge in (5,6):bank=2;shade=51
            elif kind=='screen':
                if .1<u<.9 and .12<v<.67:
                    bank=1;shade=27
                    if (y%7==2 and .17<u<.74 and (x//4+y//7+seed)%7<5) or abs(u-.78)<.02:bank=2;shade=49
                elif v>.78 and x%8<4 and y%6<3:bank=2 if x%24 else 3;shade=35
                elif edge<3:bank=1;shade=23
            elif kind=='light':
                if edge<3:bank=1;shade=33
                else:shade=59 if (x if height>width else y)%5 else 46
            elif kind=='glass':
                shade=40+int(u*14-v*7)
                if (x+y)%71<3:bank=2;shade=41
                if edge<2:bank=1;shade=25
            elif kind=='grate':
                rail = (x%16<3 or y%16<3) if 'ladder' not in name else (x<4 or x>=width-4 or y%12<3)
                if not rail:
                    if masked:pixels.append(255);continue
                    bank=1;shade=10
                else:shade=50 if (x+y)%3 else 33
            elif kind=='hazard':
                bank=0 if (x+y)//12%2 else 1
            elif kind=='sign':
                if edge<3 or height*.35<y<height*.43 and width*.18<x<width*.82:bank=2;shade=52
                elif height*.57<y<height*.63 and width*.28<x<width*.72:bank=2;shade=47
            elif kind=='sky':shade=int(28+28*y/height)
            pixels.append(min(254,bank*64+max(0,min(63,shade))))
    mips=[bytes(pixels)];w=width;h=height
    for _ in range(3):
        prior=mips[-1];out=bytearray()
        for y in range(h//2):
            for x in range(w//2):
                cells=[prior[(y*2+dy)*w+x*2+dx] for dy in (0,1) for dx in (0,1)]
                opaque=[p for p in cells if not masked or p!=255]
                if len(opaque)<2:out.append(255);continue
                bank=max(range(4),key=lambda b:sum(p//64==b for p in opaque))
                values=[p%64 for p in opaque if p//64==bank]
                out.append(min(254,bank*64+round(sum(values)/len(values))))
        mips.append(bytes(out));w//=2;h//=2
    return mips,palette,kind
