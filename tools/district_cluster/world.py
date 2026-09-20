"""Public, deterministic 9×9 campaign atlas. No credentials or runtime state."""
BASES = {10: 0, 16: 1, 64: 1, 70: 0}
RELAYS = (13, 37, 43, 67)
HUB = 40
PREFIXES = ('Ashen', 'Pilgrim', 'Cinder', 'Helix', 'Vesper', 'Cipher', 'Iron', 'Crown', 'Obsidian')
OUTSKIRTS = ('Scrap Warrens', 'Drainage Slums', 'Ash Wastes', 'Salvage Yards', 'Outer Tenements', 'Freight Ruins', 'Shanty Market', 'Cooling Fields')
PERIMETERS = ('Gatehouse', 'Barracks', 'Foundry', 'Archives', 'Chapel', 'Transit Works', 'Armoury', 'Residential Stack')


def atlas():
    rows = {}
    for i in range(81):
        x, y = i % 9, i // 9
        cx, cy = x // 3 * 3 + 1, y // 3 * 3 + 1
        center = cy * 9 + cx
        ring = [j for j in range(81) if j % 9 // 3 == x // 3 and j // 9 // 3 == y // 3 and j != center]
        role = 'homebase' if i in BASES else 'relay' if i in RELAYS else 'hub' if i == HUB else 'perimeter' if center in BASES else 'outskirts'
        suffix = ('Citadel' if role == 'homebase' else 'Relay Station' if role == 'relay' else 'Concord Inner City' if role == 'hub'
                  else (PERIMETERS if role == 'perimeter' else OUTSKIRTS)[ring.index(i)])
        name = suffix if role == 'hub' else PREFIXES[center // 9 // 3 * 3 + center % 9 // 3] + ' ' + suffix
        profile = 'closed' if role in ('homebase', 'hub', 'relay') else ('open' if role == 'outskirts' and ring.index(i) in (2, 3, 7) else 'mixed' if i % 3 else 'closed')
        links = {}
        for j, exit_, entry in ((i-1, [-124,1,0], [120,1,0]), (i+1, [124,1,0], [-120,1,0]), (i-9, [0,1,-124], [0,1,120]), (i+9, [0,1,124], [0,1,-120])):
            if 0 <= j < 81 and (abs(j-i) == 9 or j//9 == y):
                links[f'd{j:02}'] = dict(exit=exit_, entry=entry, yaw=0)
        terminals = {}
        if i == HUB:
            for j, pos in zip(RELAYS, ([-13,1,-13],[-13,1,13],[13,1,-13],[13,1,13])):
                terminals[f'd{j:02}'] = dict(exit=pos, entry=[0,1,5], yaw=0, terminal=True)
        rows[f'd{i:02}'] = dict(gateway=f'g{i//4:02}', map_slot=i%16, asset_id=i, links=links, terminals=terminals, draining=False,
            campaign_role=role, name=name, profile=profile, initial_owner=BASES.get(center, -1), homebase=f'd{center:02}' if center in BASES else None,
            perimeter=[f'd{j:02}' for j in ring] if role == 'homebase' else [], threshold=30 if role in ('homebase','relay') else 10 if role == 'perimeter' else 0,
            capture=[0,.3,0], capture_radius=8, grid=[x,y])
    return rows
