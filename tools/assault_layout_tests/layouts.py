"""CC0 expanded default Assault layouts; coordinates are Quake units.

Apply topology changes in the source map's coordinates, then expand horizontal
distances only. Door clearance, stair rise, water depth and player height stay
unchanged. These are reference-informed estimates, not measured retail geometry.
"""
import re

SCALES = {'hislop': (1.75, 1.25), 'frigate': (1.6, 1.3)}
POINT = re.compile(r'\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)')


def refine(a, entities, kind):
    if kind == 'hislop':
        hislop(a)
    else:
        frigate(a)
    sx, sy = SCALES[kind]

    def brush(text):
        return POINT.sub(lambda m: '( %g %g %g )' %
                         (float(m[1])*sx, float(m[2])*sy, float(m[3])), text)

    def fields(row):
        if 'origin' in row:
            x, y, z = map(float, row['origin'].split())
            # Pickups add a fixed 16-unit centre offset at runtime, not a scaled one.
            pickup = row['classname'].startswith(('weapon_', 'item_')) and not row['classname'].startswith('item_flag')
            offset = 16 if pickup else 0
            row['origin'] = '%g %g %g' % ((x+offset)*sx-offset, (y+offset)*sy-offset, z)
        for key, factor in [('target_x', sx), ('target_y', sy), ('train_loop', sx)]:
            if key in row:row[key] = '%g' % (float(row[key])*factor)
        # Preserve the same duration of the repeating scenery cycle after stretching X.
        if row.get('classname') == 'info_train_motion':row['speed'] = '%g' % (float(row['speed'])*sx)

    a.brushes[:] = [brush(b) for b in a.brushes]
    for row in a.entities:fields(row)
    for i, (row, b) in enumerate(entities):
        fields(row);entities[i] = row, brush(b)
    a.name = 'as_' + kind


def hislop(a):
    metal, floor, trim = 'hs_wall', 'met_blu_tile', 'met_blu_trim16'
    # Cover the entire seam, including both service walkways. Overlap both decks
    # to avoid tiny BSP cracks; rail the outer ends, not the walking route.
    for end in [-1776, -1136, -496, 144, 784, 1424]:
        a.box((end-8,-304,-16),(end+40,304,0),'aqpanl10')
        for y in [-304,292]:
            a.box((end-40,y,0),(end+72,y+12,48),trim)
    a.box((-2408,-136,-16),(-2376,136,0),'aqpanl10')
    # Low guards along the exposed freight decks and the acid-tank catwalks.
    # Falling/knockback over the side remains possible, but crossing cars is safe.
    for c in [-2080,-1440,-800,-160]:
        for y in [-304,292]:a.box((c-304,y,12),(c+304,y+12,40),trim)
    # CAR 3: four defender rooms open into a central passage, matching the
    # reference's A/B/C/D spawn-room organization instead of a single supply tube.
    for x in [448,592]:
        for lo,hi in [(-184,-64),(64,184)]:a.box((x,lo,0),(x+12,hi,128),metal)
    for y in [-64,52]:
        for lo,hi in [(448,472),(560,632),(720,768)]:a.box((lo,y,0),(hi,y+12,128),metal)
        for lo,hi in [(472,560),(632,720)]:a.box((lo,y,112),(hi,y+12,128),trim)
    spawns=[(504,-120,24),(680,-120,24),(504,120,24),(680,120,24)]
    old=[e for e in a.entities if e['classname']=='info_player_team2']
    for row,p in zip(old,spawns):row['origin']='%g %g %g'%p
    for i,p in enumerate(spawns):
        a.ent('light',(p[0],p[1],96),light=170,_color='.55 .8 1',delay=2)
        # Supply stays off the spawn capsule; independent rooms have visible numbers.
        for n in range(i+1):a.box((p[0]-32+n*16,176 if p[1]>0 else -184,56),(p[0]-24+n*16,184 if p[1]>0 else -176,88),'aqpanl10')
    def bulkhead(x,z,opening):
        lo,hi=opening
        for y0,y1 in [(-184,lo),(hi,184)]:a.box((x,y0,z),(x+16,y1,304),metal)
        a.box((x,lo,z+112),(x+16,hi,304),trim)
    # CAR 2: separate upper passenger compartments and alternating doorways.
    bulkhead(1104,144,(-128,-16))
    # CAR 1: switch at the far end of the upper control room, above the cabin.
    # The roof hatch enters the preceding room; the switch still requires crossing
    # a doorway. Returning to the stair and lower service passage provides defense time.
    bulkhead(1968,144,(16,144))
    a.box((2016,-168,144),(2040,-64,200),'comp1_6')
    for row in a.entities:
        if row['classname']=='info_as_objective' and row.get('step')=='1':row['origin']='2016 64 168'
        # Respawn before the last car, rather than next to the defending gun mount.
        if row['classname']=='info_as_spawn' and row.get('checkpoint')=='2' and row.get('role')=='attack':
            _,y,z=row['origin'].split();row['origin']='1464 '+y+' '+z
    a.ent('light',(2016,64,248),light=220,_color='.5 .85 1',delay=2)


def frigate(a):
    metal,trim='met_brn_block','met_blu_trim16'
    def partition(x,y0,y1,z,top,opening):
        lo,hi=opening
        for near,far in [(y0,lo),(hi,y1)]:
            if far>near:a.box((x,near,z),(x+16,far,top),metal)
        a.box((x,lo,z+112),(x+16,hi,top),trim)
    # Aft crew room is distinct from the mess. The negative-Y stairwell remains
    # open, with no lintel cutting across the rising player's head clearance.
    partition(-768,-64,288,160,320,(64,192))
    for x in [-1008,-896]:
        a.box((x,208,160),(x+80,272,184),'med_wood2_plk1')
        a.box((x,208,224),(x+80,272,240),trim)
    # Additional stores compartment separates warehouse/bar from the exposed quay.
    partition(-736,-1384,-840,0,272,(-1136,-944))
    # Two parallel lower-room routes: main hall with an offset machinery screen,
    # and a starboard service route using the extra openings authored in the base.
    a.box((-448,-288,0),(-416,-192,112),'met_grn_panel1')
    a.box((-448,-48,0),(-416,64,112),'met_grn_panel1')
    # Longitudinal partition makes this an actual enclosed flank, rather than an
    # ankle-high suggestion of a corridor. Existing cross-room openings stay open.
    a.box((-592,64,128),(-224,80,160),metal)
    for x in [-544,-304]:
        a.ent('light',(x,112,112),light=180,_color='.4 .7 1',delay=2)
