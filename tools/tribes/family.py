"""Build a coherent Light/Medium/Heavy family over KEIV's fitted MEC-VAL suit.
Run through Blender MCP. Source terms are retained in every exported VRM.
"""
import struct, hashlib
from pathlib import Path
ROOT=Path('/home/blux/Documents/FPSloppa')
p=ROOT/'tools/tribes/model.py'
exec(compile(p.read_text().split('report={};anchors={}')[0].replace("'Tribes Arsenal'","'Tribes Armour Family'").replace("'finish.png'","'armour-finish.png'"),str(p),'exec'))
def xyz(v):return (-v[0],-v[2],v[1])
exec(compile((ROOT/'tools/tribes/body_shapes.py').read_text(),'body_shapes.py','exec'))
import importlib.util
spec=importlib.util.spec_from_file_location('mec_suit',ROOT/'tools/tribes/mec_suit.py');mec=importlib.util.module_from_spec(spec);spec.loader.exec_module(mec)

palette=['b6bcbc','263138','586770','c1bfab','121b20','66c7d8','d6ae56','8d9ca4']
for i,mat in enumerate(mats):
    mat.name='Tribes Team Panels' if i==0 else 'Tribes Status Light' if i==5 else 'Tribes Armour Finish '+str(i)
    mat.diffuse_color=tuple(int(palette[i][j:j+2],16)/255 for j in (0,2,4))+(1,)
    bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bsdf.inputs['Metallic'].default_value=.32 if i==0 else .5
    bsdf.inputs['Roughness'].default_value=.57
    bsdf.inputs['Emission Strength'].default_value=.35 if i==5 else 0
image.pack()
suit_image=bpy.data.images.load(str(OUT/'armour-suit.png'),check_existing=True);suit_image.pack()
suit=bpy.data.materials.new('MEC-VAL / KEIV / Fitted suit');suit.use_nodes=True;suit.diffuse_color=(.07,.09,.10,1)
bsdf=next(n for n in suit.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bsdf.inputs['Metallic'].default_value=.12;bsdf.inputs['Roughness'].default_value=.8
tex=suit.node_tree.nodes.new('ShaderNodeTexImage');tex.image=suit_image;suit.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])

def panel(name,outline,z,depth=.025,mat=0):
    """Connected planar shield with an inset face and a broad chamfered edge."""
    n=len(outline);cx=sum(v[0] for v in outline)/n;cy=sum(v[1] for v in outline)/n
    vs=[(x,y,z+depth) for x,y in outline]+[(x,y,z+.008) for x,y in outline]+[(cx+(x-cx)*.86,cy+(y-cy)*.91,z) for x,y in outline]
    faces=[tuple(range(n-1,-1,-1)),tuple(range(2*n,3*n))]
    for a in [0,n]:
        for i in range(n):j=(i+1)%n;faces.append((a+i,a+j,a+j+n,a+i+n))
    return mesh(name,vs,faces,mat,0)

def plate(name,pos,size,mat=0):
    x,y,z=pos;w,h,depth=size
    outline=[(-.34,-.5),(.34,-.5),(.5,-.30),(.5,.28),(.28,.5),(-.28,.5),(-.5,.28),(-.5,-.30)]
    return panel(name,[(x+a*w,y+b*h) for a,b in outline],z,depth,mat)

def bolt(name,pos,r=.008,mat=3,axis='z'):
    x,y,z=pos;vs=[]
    for depth in [-.003,.003]:
        for i in range(8):
            a=math.tau*i/8;u=math.cos(a)*r;v=math.sin(a)*r
            vs.append((x+u,y+v,z+depth) if axis=='z' else (x+depth,y+u,z+v))
    return mesh(name,vs,[tuple(range(7,-1,-1)),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)],mat,0)

def rail(name,start,end,width=.016,depth=.016,mat=2):
    a=Vector(start);b=Vector(end);ob=box(name,(a+b)*.5,(width,(b-a).length,depth),mat)
    origin=Vector(xyz((a+b)*.5));q=Vector(xyz((0,1,0))).rotation_difference(Vector(xyz(b-a)).normalized())
    for v in ob.data.vertices:v.co=origin+q@(v.co-origin)
    return ob

exec(compile((ROOT/'tools/tribes/heavy_shell.py').read_text(),'heavy_shell.py','exec'))
BUILD_CLASSES=globals().get('BUILD_CLASSES',['light','medium','heavy'])
report=json.loads((OUT/'body-report.json').read_text()) if (OUT/'body-report.json').exists() else {}
for level,name in enumerate(['light','medium','heavy']):
    class_index=level
    light=name=='light'
    # The previous Light shell is now Medium. Scout protection exposes most
    # of the common suit; Heavy has its own enclosed, angular shell.
    level=0 if class_index<2 else 2
    ad=bpy.data.armatures.new(name+'_family_humanoid');rig=bpy.data.objects.new(name+'_family_rig',ad);scene.collection.objects.link(rig)
    for ob in scene.objects:ob.select_set(False)
    rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
    for key,(start,end,parent) in BONES.items():
        bone=ad.edit_bones.new(key);bone.head=xyz(start);bone.tail=xyz(end)
        if parent:bone.parent=ad.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    parts=[];bound=[]
    under=mec.extract(ROOT,scene,rig,BONES,xyz,suit,level,keep_feet=name!='heavy');bound.append(under)
    under_tris=sum(len(p.vertices)-2 for p in under.data.polygons)
    def bind(key,begin):
        for ob in parts[begin:]:
            vg=ob.vertex_groups.new(name=key);vg.add(list(range(len(ob.data.vertices))),1,'REPLACE');ob.parent=rig
            mod=ob.modifiers.new('Humanoid skin','ARMATURE');mod.object=rig
            # All non-team, non-emissive hardware shares one draw surface;
            # colour variation comes from its retained atlas coordinates.
            if ob.data.materials[0] not in [mats[0],mats[5]]:ob.data.materials[0]=mats[1]
            bound.append(ob)
    def chunk(key,fn):
        start=len(parts);fn();bind(key,start)
    if name=='heavy':
        build_heavy(bind)
    else:
        start=len(parts)
        loft('Unified waist girdle',(0,0,0),[(.805,.145,.12,0),(.855,.173,.13,0),(.91,.16,.12,0)],1,angular=True)
        plate('Waist lock',(0,.87,-.14),(.10,.085,.03),2)
        for sign in ([] if light else [-1,1]):
            plate('Hip shell',(sign*.158,.87,-.08),(.12,.16,.045),0)
            plate('Hip inset',(sign*.165,.86,-.13),(.068,.085,.016),2)
        bind('Hips',start)
        start=len(parts)
        for y,w in ([] if light else [(1.0,.23),(1.055,.255),(1.11,.28)]):
            plate('Abdominal lamella',(0,y,-.105), (w,.065,.027),1)
        if not light:plate('Abdominal shield',(0,1.073,-.14),(.13,.10,.02),0)
        bind('Spine',start)
        start=len(parts)
        width=[.36,.42,.53][level];front=[-.14,-.175,-.215][level]
        if not light:loft('Torso foundation',(0,0,0),[(1.10 if level==2 else 1.13,width*.34,.108,0),(1.21,width*.5,-front*.88,0),(1.33,width*.50,-front*.92,0),(1.385,width*.34,.105,0)],1,angular=True)
        for sign in [-1,1]:
            poly=[(.012,1.20),(.04,1.16),(width*.37,1.20),(width*.51,1.285),(width*.43,1.365),(.036,1.355),(.012,1.305)]
            if light:poly=[(.012,1.265),(.035,1.24),(.112,1.265),(.14,1.31),(.112,1.35),(.025,1.345),(.012,1.31)]
            panel('Split chevron breastplate',[(x*sign,y) for x,y in poly],front,.038,0)
            if not light:rail('Clavicle cap',(sign*.025,1.373,front+.028),(sign*width*.41,1.38,front+.028),.024,.02,3)
            bolt('Chest fastener',(sign*(.09 if light else width*.35),1.31,front-.004))
            # Repeated factory marks tie all classes to the same equipment family.
            for mark in range(class_index+1):box('Class tally',(sign*(.068 if light else width*.29),(1.28 if light else 1.265)-mark*.022,front-.004),(.032,.008,.006),6)
            if not light:
                plate('Side rib plate',(sign*width*.39,1.18,front+.075),(.085,.13,.033),2)
                panel('Scapula shell',[(sign*x,y) for x,y in [(.015,1.19),(width*.42,1.20),(width*.46,1.35),(.04,1.39)]],.12+level*.025,-.035,0)
        plate('Sternum lock',(0,1.307,front-.012),(.045,.115,.027),2)
        box('Status slit',(0,1.33,front-.02),(.012,.031,.007),5)
        # Open collar leaves the original neck visible, including fallback heads.
        for sign in ([] if light else [-1,1]):
            rail('Collar jaw',(sign*.078,1.395,-.053),(sign*.13,1.39,.09),.023,.035,2)
        if not light:rail('Rear collar',(-.125,1.40,.098),(.125,1.40,.098),.028,.03,2)
        plate('Pack dock',(0,1.265,.175+level*.025),(.19,.22,-.025),1)
        if level>0:
            for sign in [-1,1]:
                loft('Shoulder yoke',(sign*.18,0,.045),[(1.295,.065,.12,0),(1.415,.065,.12,0),(1.448,.035,.073,0)],2,angular=True)
                plate('Heavy flank shield',(sign*.215,1.13,-.143),(.11,.21,.042),0)
        bind('Chest',start)
        if name!='heavy':
            start=len(parts)
            # Flexible collar conceals the head-swap seam while following the
            # avatar's neck. Open ends cannot intersect the face with a solid cap.
            loft('Fitted neck gaiter',(0,0,0),[(1.345,.117,.093,0),(1.395,.098,.084,0),(1.455,.082,.077,0),(1.482,.084,.078,0)],4,segments=16,capped=False)
            loft('Neck gaiter rim',(0,0,0),[(1.465,.085,.080,0),(1.484,.087,.081,0),(1.485,.082,.076,0),(1.465,.080,.075,0)],2,segments=16,capped=False)
            bind('Neck',start)
        for side,sign in [('Left',1),('Right',-1)]:
            start=len(parts)
            rx=[.115,.145,.19][level];rz=[.105,.14,.19][level];top=[.10,.128,.12][level]
            if light:rx=.075;rz=.079;top=.05
            loft('Pauldron seal',(sign*.29,1.375,0),[(-.085,rx*.87,rz*.89,0),(.06,rx*.94,rz*.9,0)],1,angular=True)
            loft('Chamfered pauldron',(sign*.30,1.38,0),[(-.060,rx,rz,0),(.035,rx,rz,0),(top*.82,rx*.82,rz*.80,0),(top,rx*.53,rz*.56,0)],0,angular=True)
            if not light:
                plate('Pauldron brow',(sign*.305,1.412,-rz-.013),(.14+level*.028,.074,.03),2)
                for y in [1.385,1.412]:box('Shoulder vent',(sign*.31,y,-rz-.045),(.065,.008,.005),4)
                for x in [-.048,.048]:bolt('Shoulder rivet',(sign*.30+x,1.449,-rz*.82-.006),.006)
            # Upper-arm plate remains clear of the elbow as the sleeve bends.
            if not light:plate('Bicep armour',(sign*.438,1.38,-.069),(.12,.12+level*.016,.029),1 if level==0 else 0)
            bind(side+'UpperArm',start)
            start=len(parts)
            if not light:loft('Elbow seal',(sign*.528,1.36,0),[(-.042,.060,.065,0),(.04,.061,.066,0)],4,'x',angular=True)
            # Axis-aligned loft, mirrored at the mesh level for symmetric cuffs.
            rings=[(-.089,.071+level*.009,.073+level*.01,0),(-.04,.077+level*.013,.08+level*.012,-.006),(.08,.048,.054,0),(.116,.046,.05,0)]
            ob=loft('Tapered forearm shell',(sign*.638,1.36,0),rings,0,'x',angular=True) if not light else None
            if ob and sign<0:
                for v in ob.data.vertices:v.co.x=2*xyz((sign*.638,0,0))[0]-v.co.x
                bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
            plate('Vambrace inset',(sign*.633,1.36,-.063 if light else -.088-level*.012),(.13,.053,.012),0 if light else 2)
            bolt('Vambrace lock',(sign*.605,1.36,-.069 if light else -.105-level*.012),.008)
            loft('Sealed wrist',(sign*.763,1.36,0),[(-.023,.049,.054,0),(.014,.049,.054,0)],1,'x',angular=True)
            bind(side+'LowerArm',start)
            start=len(parts)
            # Fallback gloves only; runtime removes these when original hands exist.
            hard_oval('Fallback glove',(sign*.825,1.36,0),(.087,.11,.105),4,'x')
            plate('Glove knuckle',(sign*.838,1.396,-.005),(.075,.044,.048),2)
            for dz in [-.033,-.011,.011,.033]:hard_oval('Glove finger',(sign*.889,1.35,dz),(.040,.063,.019),4,'x')
            hard_oval('Glove thumb',(sign*.824,1.315,-.053),(.045,.063,.036),4,'x');bind(side+'Hand',start)
            start=len(parts)
            w=[.139,.16,.18][level];depth=[.083,.108,.135][level]
            if not light:
                plate('Thigh foundation',(sign*.135,.70,-depth+.02),(w+.025,.29,.04),1)
                plate('Thigh shield',(sign*.135,.711,-depth),(w,.28,.034),0)
                plate('Thigh longitudinal inlay',(sign*.135,.698,-depth-.005),(.028,.175,.01),2)
                bolt('Thigh lock',(sign*.135,.786,-depth-.01),.007)
            if level>0:
                loft('Outer thigh shell',(sign*.135,0,.012),[(.59,w*.48,.070,0),(.69,w*.68,depth*.84,0),(.805,w*.64,depth*.77,0),(.835,w*.40,.056,0)],1,angular=True)
                plate('Outer thigh facing',(sign*(.135+w*.42),.73,-.027),(.066,.19,.035),2)
            bind(side+'UpperLeg',start)
            start=len(parts)
            width=[.151,.177,.211][level];d=[.095,.119,.148][level]
            if level>0:
                loft('Enclosed greave',(sign*.135,0,0),[(.10,width*.40,.073,0),(.16,width*.5,d*.87,0),(.34,width*.47,d*.80,0),(.419,width*.34,.068,0)],1,angular=True)
            if not light:
                plate('Greave shield',(sign*.135,.285 if level==2 else .265,-d),(width,.23 if level==2 else .283,.041),0)
                plate('Greave ridge',(sign*.135,.285 if level==2 else .265,-d-.007),(.039,.175 if level==2 else .215,.02),2)
                plate('Knee backing',(sign*.135,.466,-.071),(.16+level*.026,.146,.044),1)
            if light:loft('Knee pad strap',(sign*.135,0,0),[(.447,.052,.057,0),(.485,.052,.057,0)],4,angular=True)
            plate('Shared knee cap',(sign*.135,.466,-.078 if light else -.099),(.105 if light else .136+level*.023,.078 if light else .112,.026 if light else .035),0)
            box('Knee seam',(sign*.135,.465,-.085 if light else -.106),(.06,.008,.006),2)
            for x in ([] if light else [-.041,.041]):bolt('Greave fixing',(sign*.135+x,.35,-d-.005),.006)
            if level==2:
                for x in [-.066,.066]:rail('Heavy shin reinforcement',(sign*.135+x,.20,-d+.018),(sign*.135+x,.35,-d+.018),.018,.02,2)
            bind(side+'LowerLeg',start)
            if name!='heavy':continue
            start=len(parts)
            w=[.092,.101,.114][level]
            loft('Shared boot',(sign*.135,0,-.06),[(.022,w,.155,0),(.055,w,.162,0),(.09,w*.92,.147,0),(.139,w*.62,.071,.04)],1,angular=True)
            plate('Armoured toe',(sign*.135,.07,-.213),(w*1.85,.079,.083),2)
            box('Tread sole',(sign*.135,.015,-.062),(w*2,.028,.32),4)
            for z in [-.17,-.09,0]:box('Tread lug',(sign*.135,.009,z),(w*2+.008,.016,.025),4)
            bind(side+'Foot',start)
    for ob in scene.objects:ob.select_set(False)
    for ob in bound:ob.select_set(True)
    bpy.context.view_layer.objects.active=under;bpy.ops.object.join();under.name='Tribes_'+name+'_Body'
    # Joining preserves a single armature modifier and all canonical weights.
    for mod in list(under.modifiers)[1:]:under.modifiers.remove(mod)
    rig.select_set(True)
    if name not in BUILD_CLASSES:
        rig.location.x=class_index*2.2
        continue
    filename=OUT/('body_'+name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(filename),use_selection=True,use_active_scene=True,export_yup=True)
    raw=filename.read_bytes();length,kind=struct.unpack_from('<II',raw,12);doc=json.loads(raw[20:20+length]);binary=raw[20+length:]
    nodes={n.get('name'):i for i,n in enumerate(doc['nodes'])}
    source_raw=(ROOT/'tools/tribes/sources/mec_val_white_fox.vrm').read_bytes()
    assert hashlib.sha256(source_raw).hexdigest()=='b8d7b1cbce1279098d545e61ebf55f61d240e2e88ae9e971dcbc02f9e75a302e'
    source_len=struct.unpack_from('<I',source_raw,12)[0]
    meta=json.loads(source_raw[20:20+source_len])['extensions']['VRM']['meta'].copy()
    meta.pop('texture',None);meta.update(title='FPSloppa '+name.title()+' Armour / MEC-VAL',version='4.0' if name=='heavy' else '3.0',author='KEIV; FPSloppa contributors',reference='MEC-VAL-白狐 fitted suit by KEIV, modified; new shell geometry by FPSloppa. See deathmatch/weapons/tribes/SOURCES.md.')
    doc.setdefault('extensionsUsed',[]).append('VRM');doc.setdefault('extensions',{})['VRM']={
        'exporterVersion':'FPSloppa coordinated armour family / Heavy 4','specVersion':'0.0','meta':meta,
        'humanoid':{'humanBones':[{'bone':k[0].lower()+k[1:],'node':nodes[k],'useDefaultValues':True} for k in BONES]},
        'firstPerson':{'firstPersonBone':nodes['Head'],'firstPersonBoneOffset':{'x':0,'y':0,'z':0},'meshAnnotations':[]},
        'blendShapeMaster':{'blendShapeGroups':[]},'secondaryAnimation':{'boneGroups':[],'colliderGroups':[]},
        'materialProperties':[{'name':m.get('name','Armour'),'shader':'VRM_USE_GLTFSHADER','renderQueue':2000,'floatProperties':{},'vectorProperties':{},'textureProperties':{},'keywordMap':{},'tagMap':{}} for m in doc.get('materials',[])]}
    data=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode();data+=b' '*(-len(data)%4)
    vrm=struct.pack('<III',0x46546C67,2,20+len(data)+len(binary))+struct.pack('<II',len(data),0x4E4F534A)+data+binary
    (OUT/('body_'+name+'.vrm')).write_bytes(vrm)
    report[name]={'triangles':sum(len(f.vertices)-2 for f in under.data.polygons),'undersuit_triangles':under_tris,'bones':len(BONES),'surfaces':len(doc['materials']),'head_mesh':False,'spring_groups':0,'source_sha256':'b8d7b1cbce1279098d545e61ebf55f61d240e2e88ae9e971dcbc02f9e75a302e'}
    rig.location.x=class_index*2.2
(OUT/'body-report.json').write_text(json.dumps(report,indent=2)+'\n')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active;space.region_3d.view_distance=6.7;space.region_3d.view_location=Vector((2.2,0,.85));space.region_3d.view_rotation=Vector((0,-1,0)).to_track_quat('-Z','Y');space.overlay.show_overlays=False
bpy.data.libraries.write(str(OUT/'tribes-bodies.blend'),{scene},fake_user=True,compress=True)
print(json.dumps(report))
