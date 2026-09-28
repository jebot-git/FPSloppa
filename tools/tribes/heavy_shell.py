"""Original Heavy shell, built over the shared KEIV suit by family.py.
Broad load-bearing forms follow the reviewed Tribes / mechanical-armour
references; no donor mesh or texture is copied into this shell.
"""

def heavy_box(name,pos,size,mat=1):
    # Flat seams and broad chamfers carry the shape; small fixtures need no
    # multi-segment bevels at VR multiplayer viewing distances.
    x,y,z=pos;a,b,c=[s/2 for s in size]
    return mesh(name,[(x+dx*a,y+dy*b,z+dz*c) for dx,dy,dz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat,0)

def heavy_relief(name,outline,mat=0,depth=.028,ridge=.015,offset=0):
    """Connected, faceted armour with independently canted outline corners."""
    outline=[(x,y,z-offset) for x,y,z in outline]
    n=len(outline);center=sum((Vector(p) for p in outline),Vector())/n
    front=[Vector(p) for p in outline]
    inset=[center+(p-center)*.83+Vector((0,0,-ridge)) for p in front]
    vertices=[p+Vector((0,0,depth)) for p in front]+front+inset
    vertices.append(center+Vector((0,0,-ridge*1.3)))
    faces=[tuple(range(n-1,-1,-1))]
    for i in range(n):
        j=(i+1)%n
        faces.extend([(i,j,n+j,n+i),(n+i,n+j,2*n+j,2*n+i),(2*n+i,2*n+j,3*n)])
    return mesh(name,vertices,faces,mat,0)

def heavy_mirror(ob,axis='x'):
    for v in ob.data.vertices:v.co[0 if axis=='x' else 1]*=-1
    bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
    return ob

def build_heavy(bind):
    start=len(parts)
    loft('Heavy pelvic chassis',(0,0,0),[(.805,.175,.13,0),(.855,.211,.152,0),(.922,.205,.15,0)],1,angular=True)
    heavy_relief('Pelvic shield',[(-.115,.907,-.16),(.115,.907,-.16),(.127,.858,-.177),(.067,.802,-.171),(-.067,.802,-.171),(-.127,.858,-.177)],2)
    plate('Belt coupling',(0,.881,-.204),(.077,.055,.020),3)
    for sign in [-1,1]:
        plate('Hip hinge housing',(sign*.190,.871,-.072),(.082,.117,.05),2)
        bolt('Hip hinge pin',(sign*.191,.877,-.087),.016,3)
    bind('Hips',start)

    start=len(parts)
    for y,rx,rz in [(.962,.185,.146),(1.019,.195,.159),(1.075,.207,.174)]:
        loft('Overlapping abdominal ring',(0,0,-.006),[(y-.031,rx*.98,rz*.94,0),(y+.019,rx,rz,0),(y+.035,rx*.98,rz*.93,0)],1,angular=True)
        plate('Abdominal lamella',(0,y,-rz-.019),(.255,.060,.024),2)
    plate('Upper abdomen team insert',(0,1.082,-.204),(.173,.072,.022),0)
    # Spine brace remains below the backpack's chest mounting.
    plate('Lumbar plate',(0,1.03,.163),(.24,.15,-.029),0)
    bind('Spine',start)

    start=len(parts)
    loft('Heavy cuirass chassis',(0,0,-.006),[(1.09,.205,.165,0),(1.18,.258,.204,0),(1.31,.281,.201,0),(1.39,.19,.143,0)],1,angular=True)
    for sign in [-1,1]:
        # Canted cheek plates form a single broad cuirass, with a central
        # seam and the family's existing chevron edge and three class marks.
        outline=[(.014,1.17,-.215),(.115,1.125,-.188),(.228,1.182,-.197),(.268,1.291,-.175),(.195,1.377,-.160),(.058,1.376,-.190),(.014,1.315,-.234)]
        heavy_relief('Canted breastplate',[(sign*x,y,z) for x,y,z in outline],0,.050,.016,.023)
        if sign==1:
            plate('Chest access inset',(sign*.142,1.294,-.258),(.083,.061,.013),2)
            for i in range(3):heavy_box('Heavy class tally',(sign*(.119+i*.023),1.297,-.262),(.008,.026,.004),6)
        bolt('Cuirass fastening',(sign*.202,1.222,-.253),.011,3)
        rail('Upper chest rail',(sign*.065,1.388,-.184),(sign*.188,1.39,-.157),.019,.025,3)
        plate('Rear scapula plate',(sign*.146,1.284,.205),(.186,.218,-.028),0)
        plate('Rear cooling recess',(sign*.172,1.277,.235),(.086,.130,-.014),4)
        for y in [1.235,1.262,1.289,1.316]:heavy_box('Cooling louvre',(sign*.172,y,.249),(.078,.010,.014),2)
        # Short collar cheeks protect the neck while keeping the jaw clear.
        loft('Collar buttress',(sign*.130,0,.026),[(1.345,.055,.102,0),(1.427,.052,.084,0),(1.455,.029,.055,0)],2,angular=True)
    plate('Cuirass central latch',(0,1.267,-.263),(.061,.137,.024),2)
    heavy_box('Status slit',(0,1.306,-.268),(.012,.039,.008),5)
    plate('Pack coupling',(0,1.267,.227),(.143,.189,-.030),1)
    for y in [1.214,1.321]:heavy_box('Pack rail crossbar',(0,y,.251),(.127,.015,.017),3)
    bind('Chest',start)

    start=len(parts)
    loft('Heavy neck seal',(0,0,0),[(1.351,.108,.093,0),(1.40,.086,.076,0),(1.476,.081,.075,0)],4,segments=16,capped=False)
    loft('Heavy collar lip',(0,0,0),[(1.459,.084,.078,0),(1.480,.085,.079,0),(1.481,.080,.074,0)],2,segments=16,capped=False)
    bind('Neck',start)

    for side,sign in [('Left',1),('Right',-1)]:
        start=len(parts)
        # The inner bridge follows the shoulder; the outer overlapping plate
        # follows the upper arm. No giant rigid pod rotates into the head.
        ob=loft('Shoulder bridge',(0,1.377,0),[(.198,.054,.095,0),(.265,.083,.128,0),(.328,.079,.144,0)],2,'x',angular=True)
        if sign<0:heavy_mirror(ob)
        bind(side+'Shoulder',start)
        start=len(parts)
        ob=loft('Layered pauldron base',(0,1.371,0),[(.255,.092,.146,0),(.345,.113,.161,0),(.431,.082,.139,0)],1,'x',angular=True)
        if sign<0:heavy_mirror(ob)
        ob=loft('Pauldron roof',(0,1.425,0),[(.257,.035,.151,0),(.345,.061,.169,0),(.423,.035,.145,0)],0,'x',angular=True)
        if sign<0:heavy_mirror(ob)
        for x,y,w,h,z in [(.303,1.413,.161,.121,-.160),(.390,1.376,.131,.137,-.155)]:
            poly=[(-.50,-.35),(-.32,-.50),(.39,-.50),(.50,.26),(.20,.50),(-.43,.50)]
            heavy_relief('Stepped shoulder shell',[(sign*(x+a*w),y+b*h,z+(.022 if a>0 else 0)) for a,b in poly],0,.043,.006,.026)
        for y in [1.414,1.434]:heavy_box('Pauldron recessed vent',(sign*.302,y,-.198),(.071,.006,.006),4)
        bolt('Pauldron fixing',(sign*.364,1.386,-.205),.010,3)
        plate('Bicep shield',(sign*.464,1.36,-.078),(.080,.119,.025),2)
        bind(side+'UpperArm',start)

        start=len(parts)
        loft('Elbow joint',(sign*.53,1.36,0),[(-.031,.063,.070,0),(.031,.063,.070,0)],4,'x',angular=True)
        ob=loft('Heavy forearm chassis',(0,1.36,0),[(.554,.076,.078,0),(.604,.098,.111,0),(.700,.076,.086,0),(.761,.049,.054,0)],0,'x',angular=True)
        if sign<0:heavy_mirror(ob)
        heavy_relief('Forearm shield',[(sign*x,y,z) for x,y,z in [(.558,1.41,-.086),(.598,1.447,-.108),(.691,1.421,-.097),(.744,1.382,-.064),(.707,1.310,-.092),(.605,1.280,-.107),(.563,1.304,-.085)]],0,.042,.009,.026)
        plate('Forearm service plate',(sign*.641,1.36,-.151),(.069,.076,.023),2)
        bolt('Forearm lock',(sign*.641,1.36,-.155),.013,3)
        loft('Wrist coupling',(sign*.763,1.36,0),[(-.015,.052,.057,0),(.014,.050,.054,0)],2,'x',angular=True)
        bind(side+'LowerArm',start)

        start=len(parts)
        hard_oval('Fallback glove',(sign*.825,1.36,0),(.087,.11,.105),4,'x')
        plate('Glove knuckle',(sign*.838,1.396,-.005),(.075,.044,.048),2)
        for dz in [-.033,-.011,.011,.033]:hard_oval('Glove finger',(sign*.889,1.35,dz),(.040,.063,.019),4,'x')
        hard_oval('Glove thumb',(sign*.824,1.315,-.053),(.045,.063,.036),4,'x')
        bind(side+'Hand',start)

        start=len(parts)
        loft('Heavy thigh shell',(sign*.135,0,.003),[(.563,.081,.080,0),(.629,.111,.128,0),(.752,.123,.142,0),(.829,.103,.100,0)],1,angular=True)
        heavy_relief('Canted thigh facing',[(sign*(.135+x),y,z) for x,y,z in [(-.055,.795,-.119),(.073,.790,-.119),(.107,.710,-.126),(.072,.587,-.101),(-.047,.585,-.095),(-.080,.695,-.137)]],0,.048,.008,.031)
        plate('Thigh inset',(sign*.149,.713,-.174),(.073,.133,.017),2)
        # The hip skirts follow the femur and overlap the chassis at rest.
        plate('Articulated hip skirt',(sign*.211,.819,-.122),(.099,.140,.035),0)
        plate('Rear thigh plate',(sign*.147,.712,.142),(.153,.179,-.023),0)
        bolt('Thigh fastener',(sign*.171,.760,-.178),.010,3)
        bind(side+'UpperLeg',start)

        start=len(parts)
        loft('Knee flex seal',(sign*.135,0,0),[(.435,.073,.067,0),(.493,.077,.074,0)],4,angular=True)
        plate('Knee shield',(sign*.135,.462,-.104),(.191,.120,.036),2)
        plate('Knee team inset',(sign*.135,.467,-.112),(.120,.063,.014),0)
        loft('Heavy greave chassis',(sign*.135,0,.012),[(.119,.087,.084,0),(.210,.121,.111,0),(.340,.125,.128,0),(.413,.096,.078,0)],1,angular=True)
        heavy_relief('Greave shield',[(sign*(.135+x),y,z) for x,y,z in [(-.060,.410,-.081),(.063,.410,-.081),(.110,.338,-.119),(.096,.208,-.100),(.055,.165,-.077),(-.062,.164,-.077),(-.103,.241,-.117),(-.105,.333,-.119)]],0,.049,.010,.026)
        plate('Shin central rib',(sign*.135,.301,-.158),(.052,.167,.027),2)
        for y in [.264,.326]:bolt('Shin lock',(sign*.135,y,-.162),.009,3)
        plate('Calf service cover',(sign*.135,.296,.151),(.14,.150,-.025),0)
        for y in [.268,.299,.330]:heavy_box('Calf cooling slot',(sign*.135,y,.169),(.075,.010,.014),4)
        bind(side+'LowerLeg',start)

        start=len(parts)
        loft('Reinforced boot',(sign*.135,0,-.063),[(.018,.109,.158,0),(.046,.112,.164,0),(.092,.103,.146,0),(.139,.064,.067,.040)],1,angular=True)
        plate('Armoured toe',(sign*.135,.069,-.222),(.191,.077,.076),0)
        heavy_box('Toe separation',(sign*.135,.067,-.228),(.010,.045,.006),2)
        heavy_box('Tread sole',(sign*.135,.014,-.06),(.224,.024,.329),4)
        for z in [-.18,-.10,0]:heavy_box('Tread lug',(sign*.135,.008,z),(.233,.016,.026),2)
        bind(side+'Foot',start)
