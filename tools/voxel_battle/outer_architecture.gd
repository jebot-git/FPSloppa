extends RefCounted
## Six authored landmarks, batched into one opaque mesh per site/LOD.
## Local coordinates keep both road axes and the building entrance lanes clear.
const STONE:=Color(.53,.52,.43)
const STEEL:=Color(.29,.37,.38)
const TIMBER:=Color(.38,.28,.17)
const CANVAS:=Color(.46,.49,.31)
static func specifications() -> Array:
 return [
  spec(5,Vector3(-20,0,-18),Vector2(14,20),2,Color(.58,.62,.55),"relay control"),
  spec(5,Vector3(21,0,-18),Vector2(14,18),1,Color(.43,.49,.43),"relay power room"),
  spec(6,Vector3(-23,0,-18),Vector2(12,18),1,Color(.65,.58,.43),"crossing guardhouse"),
  spec(6,Vector3(23,0,18),Vector2(12,18),1,Color(.54,.59,.53),"crossing inspection office"),
  spec(7,Vector3(-23,0,-21),Vector2(16,20),1,Color(.56,.57,.39),"expedition laboratory"),
  spec(7,Vector3(23,0,-21),Vector2(16,20),1,Color(.54,.49,.34),"expedition bunkhouse"),
  spec(8,Vector3(-22,0,-21),Vector2(16,20),1,TIMBER,"outpost storehouse"),
  spec(8,Vector3(22,0,-21),Vector2(16,20),2,Color(.48,.38,.24),"outpost quarters"),
  spec(8,Vector3(22,0,21),Vector2(14,18),3,TIMBER,"canopy watchtower"),
  spec(9,Vector3(-20,0,-19),Vector2(14,18),1,Color(.65,.64,.57),"summit instrument lab"),
  spec(9,Vector3(20,0,19),Vector2(18,18),2,Color(.69,.69,.62),"observatory"),
  spec(10,Vector3(-25,0,-24),Vector2(14,18),1,Color(.57,.53,.41),"archaeology shelter")]
static func spec(k:int,p:Vector3,size:Vector2,floors:int,color:Color,role:String) -> Dictionary:
 return {"kind":k,"center":p,"size":size,"floors":floors,"color":color,"role":role}
static func decorate(a) -> void:
 match a.kind:
  5:relay(a)
  6:crossing(a)
  7:camp(a)
  8:outpost(a)
  9:observatory(a)
  10:ruins(a)
static func beam(a,start:Vector3,end:Vector3,width:float,color:Color) -> void:
 var middle:Vector3=(start+end)*.5
 var size:=Vector3(width,start.distance_to(end),width)
 var first:int=a.builder.vertices.size()
 a.builder.box(Vector3.ZERO,size,color)
 var rotation:=Basis(Quaternion(Vector3.UP,(end-start).normalized()))
 for i in range(first,a.builder.vertices.size()):a.builder.vertices[i]=middle+rotation*a.builder.vertices[i]
 var bounds:=AABB(a.builder.vertices[first],Vector3.ZERO)
 for i in range(first,a.builder.vertices.size()):bounds=bounds.expand(a.builder.vertices[i])
 a.render_boxes.append({"kind":a.kind,"lod":a.level,"center":bounds.get_center(),"size":bounds.size})
static func relay(a) -> void:
 var p:=Vector3(-21,0,21)
 a.box(p+Vector3(0,.25,0),Vector3(11,.5,11),STONE)
 for x in [-2.0,2.0]:
  for z in [-2.0,2.0]:a.box(p+Vector3(x,14,z),Vector3(.38,28,.38),STEEL)
 for y in range(4,29,4 if a.level==0 else 8):
  for side in [-2.0,2.0]:
   beam(a,p+Vector3(side,y-4,-2),p+Vector3(side,y,2),.18,STEEL)
   beam(a,p+Vector3(-2,y-4,side),p+Vector3(2,y,side),.18,STEEL)
 a.box(p+Vector3(0,28,0),Vector3(5,.35,5),STEEL)
 a.dish(p+Vector3(0,29,0),3.3,16 if a.level==0 else 10 if a.level==1 else 6)
 a.box(p+Vector3(0,33,0),Vector3(.22,7,.22),STEEL,false)
 for x in [17.0,25.0]:a.box(Vector3(x,1,20),Vector3(5,2,8),Color(.32,.43,.44))
 if a.level==0:
  for z in [17.0,20.0,23.0]:a.box(Vector3(21,2.15,z),Vector3(12,.2,1.3),Color(.18,.29,.34),false)
static func crossing(a) -> void:
 # Low deck sits above the existing graded pad. The terrain remains a heightfield.
 a.box(Vector3(0,.10,0),Vector3(14,.20,58),Color(.44,.45,.42))
 for side in [-1.0,1.0]:
  var x:float=side*8.2
  a.box(Vector3(x,4,0),Vector3(.45,.45,58),STEEL)
  for z in [-18.0,18.0]:a.box(Vector3(x,.45,z),Vector3(.45,.45,14),STEEL)
  for z in [-24.0,-12.0,12.0,24.0]:
   a.box(Vector3(x,2.2,z),Vector3(.45,4.4,.45),STEEL)
  if a.level<2:
   for z in [-24.0,12.0]:beam(a,Vector3(x,.6,z),Vector3(x,4,z+12),.28,STEEL)
  for z in [-24.0,24.0]:a.box(Vector3(x,.15,z),Vector3(3,.3,3),STONE)
 for z in [-28.0,0.0,28.0]:a.box(Vector3(0,4.6,z),Vector3(17,.35,.4),STEEL,false)
 if a.level==0:
  for z in range(-24,25,8):
   for x in [-5.8,5.8]:a.box(Vector3(x,.215,z),Vector3(.12,.025,4),Color(.82,.74,.39),false)
static func tent(a,p:Vector3) -> void:
 a.box(p+Vector3(0,.10,0),Vector3(11,.2,14),TIMBER)
 for side in [-1.0,1.0]:a.box(p+Vector3(side*5,1.3,0),Vector3(.16,2.6,13),CANVAS)
 for z in [-6.5,6.5]:
  for side in [-1.0,1.0]:a.box(p+Vector3(side*3,1.3,z),Vector3(4,2.6,.16),CANVAS)
 a.builder.roof(p+Vector3(0,2.6,0),Vector3(10.4,2.6,13.4),CANVAS)
 if a.level==0:
  for x in [-3.0,3.0]:a.box(p+Vector3(x,.45,0),Vector3(1.3,.7,2.4),Color(.36,.41,.30))
static func camp(a) -> void:
 for x in [-23.0,23.0]:tent(a,Vector3(x,0,23))
 a.box(Vector3(-23,.10,23),Vector3(15,.2,18),TIMBER)
 a.box(Vector3(23,.10,23),Vector3(15,.2,18),TIMBER)
 for x in [-23.0,23.0]:
  a.box(Vector3(x,.15,12.5),Vector3(3,.3,3),TIMBER)
 a.box(Vector3(36,2,-20),Vector3(3,4,5),Color(.35,.47,.45))
 a.box(Vector3(-36,5,21),Vector3(.3,10,.3),STEEL)
 a.box(Vector3(-36,10,21),Vector3(3,.2,1),Color(.82,.66,.27),false)
 if a.level==0:
  for p in [Vector3(-34,0,-10),Vector3(34,0,10)]:
   a.box(p+Vector3(0,.6,0),Vector3(3,1.2,2),Color(.56,.40,.22))
   a.box(p+Vector3(0,1.22,0),Vector3(3.15,.12,2.15),STEEL)
static func outpost(a) -> void:
 var p:=Vector3(22,0,21)
 a.box(p+Vector3(0,9.8,0),Vector3(18,.3,22),TIMBER)
 for side in [-1.0,1.0]:
  a.box(p+Vector3(side*8.6,10.6,0),Vector3(.2,1.3,22),TIMBER)
  a.box(p+Vector3(0,10.6,side*10.6),Vector3(18,1.3,.2),TIMBER)
 a.box(p+Vector3(0,15,0),Vector3(.3,10,.3),TIMBER,false)
 a.box(p+Vector3(0,19,0),Vector3(4,.25,2),Color(.69,.55,.29),false)
 # A separate open shelter and log stockpile keep the fourth quadrant distinctive.
 for x in [-27.0,-17.0]:
  for z in [16.0,29.0]:a.box(Vector3(x,2.2,z),Vector3(.5,4.4,.5),TIMBER)
 a.builder.roof(Vector3(-22,4.4,22.5),Vector3(13,2,16),Color(.26,.34,.24))
 for z in [19.0,23.0,27.0]:a.box(Vector3(-22,.6,z),Vector3(8,1.2,1.3),TIMBER)
 if a.level==0:
  for x in [16.0,28.0]:a.box(Vector3(x,9.3,21),Vector3(.7,.7,4),Color(.20,.28,.28),false)
static func dome(a,p:Vector3,radius:float) -> void:
 var sectors:int=[24,16,10][a.level];var rings:int=[8,5,3][a.level]
 for ring in rings:
  for sector in sectors:
   # A narrow telescope slit faces the south approach, not a sealed hemisphere.
   if sector==sectors/4:continue
   var vertices:Array[Vector3]=[]
   for pair in [Vector2(ring,sector),Vector2(ring+1,sector),Vector2(ring+1,sector+1),Vector2(ring,sector+1)]:
    var elevation:float=pair.x/rings*PI*.5;var angle:float=pair.y/sectors*TAU
    vertices.append(p+Vector3(cos(angle)*cos(elevation),sin(elevation),sin(angle)*cos(elevation))*radius)
   var start:int=a.builder.vertices.size()
   for v in vertices:a.builder.vertices.append(v);a.builder.colors.append(Color(.74,.78,.75).darkened(.12*ring/rings))
   a.builder.indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
static func observatory(a) -> void:
 dome(a,Vector3(20,6.6,19),9)
 a.box(Vector3(20,8.5,19),Vector3(1,4,1),STEEL,false)
 beam(a,Vector3(20,10,19),Vector3(20,13.7,25),.9,Color(.24,.31,.35))
 # Weather instruments and a low retaining terrace stay out of both access axes.
 a.box(Vector3(-21,.35,20),Vector3(22,.7,19),STONE)
 for x in [-30.0,-12.0]:a.box(Vector3(x,1.1,29),Vector3(.25,1.5,.25),STEEL)
 a.box(Vector3(-21,1.8,29),Vector3(18,.2,.2),STEEL)
 a.box(Vector3(23,4.5,-20),Vector3(.35,9,.35),STEEL)
 a.box(Vector3(23,9,-20),Vector3(3,.4,3),Color(.75,.76,.68),false)
 if a.level==0:
  for x in [17.0,23.0,29.0]:a.box(Vector3(x,.8,-28),Vector3(4,1.6,2.3),Color(.19,.32,.38))
static func ruins(a) -> void:
 # Four open precincts around the road crossroads, not an impassable solid proxy.
 for p in [Vector3(25,0,-25),Vector3(-25,0,25),Vector3(25,0,25)]:
  a.box(p+Vector3(0,.12,0),Vector3(23,.24,23),STONE)
  for side in [-1.0,1.0]:
   for sign in [-1.0,1.0]:
    a.box(p+Vector3(sign*7,2.2,side*11),Vector3(9,4.4,.9),STONE)
   a.box(p+Vector3(side*11,1.5,0),Vector3(.9,3,23),STONE)
  for x in [-6.0,6.0]:
   a.box(p+Vector3(x,3,0),Vector3(1.6,6,1.6),STONE)
   a.box(p+Vector3(x,6.1,0),Vector3(2.2,.5,2.2),STONE)
  a.box(p+Vector3(0,6.7,0),Vector3(14,.7,2),STONE)
  if a.level==0:
   for i in 5:a.box(p+Vector3(-8+i*3,.35,-5+(i%2)*3),Vector3(1.5,.7,1.1),STONE.darkened(.13))
 a.box(Vector3(25,.65,25),Vector3(4,1.3,4),Color(.58,.50,.34))
 a.box(Vector3(25,2,25),Vector3(2,1.4,2),Color(.42,.48,.42))
