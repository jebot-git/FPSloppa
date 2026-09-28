"""Small sightline corrections from the CS 1.6 video/layout study.

These are original brush adaptations, with standing-capsule doorway clearance.
"""
def nuke(a):
    # A room volume inside the upper room is unioned away by the shell builder.
    # The old 'hut' was consequently a roof with no side walls. Restore two
    # opposite entrances; their long axis matches the existing lobby/A route.
    for u,U in [(420,443)]:
        for v,V in [(285,309),(331,344)]:
            a.block(u-.6,v,u+.6,V,0,150,'wood')
            a.block(U-.6,v,U+.6,V,0,150,'wood')
        a.block(u,285,U,286.2,0,150,'wood')
        a.block(u,342.8,U,344,0,150,'wood')
        for x in [u,U]:a.block(x-.6,309,x+.6,331,112,150,'wood')
    a.sightline_checks=[
        dict(name='Hut doorway remains open',start=[414,320,48],end=[453,320,48],clear=True),
        dict(name='Hut side breaks the broad lobby angle',start=[427,280,48],end=[427,350,48],clear=False)]
    a.route('Hut doorway clearance',[[414,320,0],[431,320,0],[453,320,0]])

def inferno(a):
    # Apartments were one 31.5m-wide uninterrupted firing corridor. Two
    # staggered room partitions create clearing corners like the tutorial's
    # apartment interior without closing the balcony route or adding a boost.
    for u,low,high in [(515,554,566),(551,576,589)]:
        # Keep the wall and its cross-corridor lintel clear of the facade's
        # authored window/door frames, including their outer trim bounds.
        for decor in a.decor_checks:
            if decor['axis']!='u' or not 554 <= decor['plane'] <= 589:continue
            left,right,bottom,top=decor['rect']
            assert u+1.2 <= left or u >= right or 240 <= bottom or 96 >= top, ('Apartment partition clips decoration',u,decor)
        a.block(u,low,u+1.2,high,96,240,'wall')
        a.block(u,554,u+1.2,589,220,240,'wood')
    a.sightline_checks=[
        dict(name='Apartments north shoulder occludes',start=[478,560,144],end=[521,560,144],clear=False),
        dict(name='Apartments south shoulder occludes',start=[530,583,144],end=[578,583,144],clear=False),
        dict(name='Apartments central passage remains open',start=[478,571,144],end=[578,571,144],clear=True)]
