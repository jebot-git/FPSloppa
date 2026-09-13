"""UT99 pickup inventory adapted to our authored rooms, before horizontal scaling.
Reference facts: Liandri Archives AS-HiSpeed / AS-Frigate (links in docs).
Coordinates are our own, not extracted Epic geometry. Jump pads retain the role
of HiSpeed's four jump-boot opportunities; ammo uses FPSloppa's four shared pools.
"""
from collections import Counter

# slot: BSP fallback, shared ammunition pool, weapon grant, ammo-box grant.
WEAPONS = {
    1: ('weapon_grenadelauncher', 3, 25, 25),
    3: ('weapon_shotgun', 3, 20, 10),
    4: ('weapon_supershotgun', 1, 10, 10),
    5: ('weapon_nailgun', 0, 100, 50),
    6: ('weapon_rocketlauncher', 2, 6, 6),
    7: ('weapon_supernailgun', 3, 60, 25),
    9: ('weapon_nailgun', 0, 8, 10),
    10: ('weapon_nailgun', 0, 15, 25),
}
AMMO = ['item_spikes', 'item_shells', 'item_rockets', 'item_cells']


def inventory(kind, tiny=False):
    if kind == 'hislop':
        # Helicopter, open/container/pillar/sludge cars, then CAR 3/2/1.
        weapons = {
            3: [(-2624,-64,0), (48,64,0), (464,48,144)],
            7: [(-2560,64,0), (656,48,144)],
            10: [(-1008,32,0), (536,128,0), (672,-128,0), (1184,48,144)],
            5: [(-592,32,0), (928,48,0)],
            4: [(-1440,224,0), (1296,48,144)],
            6: [(-2256,0,0), (536,-128,0), (672,128,0), (1088,48,144)],
            9: [(1984,48,144)],
        }
        ammo = {
            3: [(-1616,176,0),(-1472,-176,0),(-1280,176,0),(48,176,0),(112,128,0),(464,112,144),(528,112,144)],
            7: [(-1184,176,0),(-1184,-176,0),(-1008,80,0),(656,112,144),(608,112,144)],
            10: [(-1008,-32,0),(656,-48,144),(1184,112,144)],
            5: [(-592,80,0),(-544,80,0),(928,96,0),(1984,64,0)],
            4: [(-1488,224,0),(-1392,224,0),(1296,112,144),(1880,-96,0)],
            6: [(-1680,176,0),(-1552,-176,0),(-704,32,0),(-656,32,0),(1088,112,144)],
            9: [(1984,112,144)],
        }
        health = [(-1040,224,0),(-976,224,0),(224,64,0),(1360,-48,0),(1408,-48,0),(1088,-64,144),(1088,0,144),(944,144,0),(1968,0,0),(2016,112,144)]
        kegs = [(-1328,-224,0),(1168,-32,144)]
        armor = [(100,(736,0,0)),(150,(-160,0,192)),(150,(848,224,0))]
    else:
        # Warehouse armory, flooded intake, lower rooms, mess deck and bridge.
        weapons = {
            1: [(-112,-112,0)],
            3: [(-1136,-1104,0),(192,96,320)],
            10: [(-944,-1264,48)],
            5: [(-1040,-1040,0),(832,-240,0)],
            4: [(736,32,-224),(-800,96,160)],
            6: [(-112,-1008,0)],
            9: [(-864,-1040,0)],
        }
        # Pairs beside each cache; the bridge shock rifle has one spare cell box.
        ammo = {}
        for slot, points in weapons.items():
            ammo[slot] = []
            for x,y,z in points:
                offsets = [(-48,0)] if slot==3 and z==320 else [(-48,0),(48,0)]
                ammo[slot] += [(x+dx,y+dy,z) for dx,dy in offsets]
        health = [(-1200,-1040,0),(-1264,-1104,0),(-800,32,160),(-528,-128,0),(-752,-64,0),(-1152,-928,0)]
        kegs = [(-976,-64,0)]
        armor = [(100,(-64,-1232,144)),(100,(-736,96,0)),(50,(32,-128,160)),(150,(480,32,-224))]
    if tiny and kind=="hislop":weapons[6][-2]=(720,128,0)
    rows = []
    def add(classname, point, **fields):
        x,y,z=point
        rows.append(dict(classname=classname,origin='%g %g %g'%(x-16,y-16,z+20),**{k:str(v) for k,v in fields.items()}))
    for slot, points in weapons.items():
        for point in points:add(WEAPONS[slot][0],point,fpsloppa_ut_weapon=slot,fpsloppa_amount=WEAPONS[slot][2])
    for slot, points in ammo.items():
        for point in points:add(AMMO[WEAPONS[slot][1]],point,fpsloppa_amount=WEAPONS[slot][3],fpsloppa_ut_ammo=slot)
    for point in health:add('item_health',point)
    for point in kegs:add('item_health',point,spawnflags=2)
    for amount,point in armor:add('item_armor2' if amount==150 else 'item_armor1',point,fpsloppa_amount=amount)
    return rows


def apply(a, kind, tiny=False):
    a.entities[:] = [row for row in a.entities if not is_pickup(row) and 'fpsloppa_roof_guard' not in row] + inventory(kind,tiny) + roof_guards(kind)


def is_pickup(row):
    name=row.get('classname','')
    return name.startswith(('weapon_','item_')) and not name.startswith('item_flag')


def counts(kind):
    rows=inventory(kind)
    return dict(total=len(rows),weapons=dict(Counter(r['fpsloppa_ut_weapon'] for r in rows if 'fpsloppa_ut_weapon' in r)),ammo=dict(Counter(r['fpsloppa_ut_ammo'] for r in rows if 'fpsloppa_ut_ammo' in r)))


def roof_guards(kind):
    if kind!='hislop':return []
    return [dict(classname='info_as_sentry',origin='%g %g %g'%(x,y,z+24),fpsloppa_roof_guard='1')
            for x,y,z in [(1728,128,320),(1952,-112,320)]]
