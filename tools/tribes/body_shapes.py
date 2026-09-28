"""Shared canonical humanoid and original loft primitives for the armour family."""
BONES={'Hips':((0,.86,0),(0,1,0),None),'Spine':((0,1,0),(0,1.17,0),'Hips'),'Chest':((0,1.17,0),(0,1.38,0),'Spine'),'Neck':((0,1.38,0),(0,1.49,0),'Chest'),'Head':((0,1.49,0),(0,1.72,0),'Neck')}
for side,sign in [('Left',1),('Right',-1)]:
 for name,start,end,parent in [('Shoulder',(.08,1.36,0),(.24,1.36,0),'Chest'),('UpperArm',(.24,1.36,0),(.52,1.36,0),side+'Shoulder'),('LowerArm',(.52,1.36,0),(.77,1.36,0),side+'UpperArm'),('Hand',(.77,1.36,0),(.91,1.36,0),side+'LowerArm'),('UpperLeg',(.135,.86,0),(.135,.49,0),'Hips'),('LowerLeg',(.135,.49,0),(.135,.11,0),side+'UpperLeg'),('Foot',(.135,.11,0),(.135,.075,-.22),side+'LowerLeg')]:BONES[side+name]=((start[0]*sign,*start[1:]),(end[0]*sign,*end[1:]),parent)
def loft(name, pos, rings, mat=0, axis='y', segments=12, angular=False,capped=True):
 """Contoured cast armour, with deliberately broad original-game facets."""
 x,y,z=pos;verts=[];faces=[]
 if angular:segments=8
 for along,r1,r2,shift in rings:
  for i in range(segments):
   a=2*math.pi*(i+.5)/segments;u=math.cos(a)*r1;v=math.sin(a)*r2+shift
   if angular:
    corner=[(-.72,-1),(.72,-1),(1,-.72),(1,.72),(.72,1),(-.72,1),(-1,.72),(-1,-.72)][i];u=corner[0]*r1;v=corner[1]*r2+shift
   verts.append((x+u,y+along,z+v) if axis=='y' else (x+along,y+u,z+v))
 for row in range(len(rings)-1):
  for i in range(segments):
   j=(i+1)%segments;k=row*segments;faces.append((k+i,k+j,k+j+segments,k+i+segments))
 if capped:faces.extend([tuple(range(segments-1,-1,-1)),tuple(range((len(rings)-1)*segments,len(rings)*segments))])
 ob=mesh(name,verts,faces,mat,0)
 if not capped:
  # An open sleeve has no enclosed volume for Blender's normal recalculation
  # to classify. Explicitly orient its first outer ring away from the axis.
  face=ob.data.polygons[0];radial=face.center-Vector(xyz(pos));radial[2 if axis=='y' else 0]=0
  if face.normal.dot(radial)<0:
   bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free();ob.data.update()
 return ob
def oval(name,pos,size,mat=0,axis='y'):
 a,b,c=size
 return loft(name,pos,[(-b*.5,a*.30,c*.30,0),(-b*.32,a*.48,c*.48,0),(b*.22,a*.50,c*.50,0),(b*.5,a*.28,c*.30,0)],mat,axis)
def hard_oval(name,pos,size,mat=0,axis='y'):
 a,b,c=size
 return loft(name,pos,[(-b*.5,a*.34,c*.40,0),(-b*.30,a*.50,c*.50,0),(b*.20,a*.50,c*.50,0),(b*.5,a*.36,c*.36,0)],mat,axis,angular=True)
