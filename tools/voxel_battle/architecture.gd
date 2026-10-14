extends RefCounted
## Shared geometry descriptions feed render LODs, physics, and entry validation.
const Fixtures=preload("res://tools/voxel_battle/light_fixtures.gd")
const Outer=preload("res://tools/voxel_battle/outer_architecture.gd")
const Builder=preload("res://tools/streamed_heightfield/structures.gd").Builder
var boxes: Array=[]
var render_boxes: Array=[]
var buildings: Array=[]
var kind:=0
var level:=0
var builder
const WALL:=.24
const DOOR:=2.0
const CLEAR_HEIGHT:=2.4
const STOREY:=3.2
func box(p: Vector3,size: Vector3,color: Color,solid: bool=true) -> void:
	builder.box(p,size,color)
	render_boxes.append({"kind":kind,"lod":level,"center":p,"size":size})
	if level==0 and solid:boxes.append({"kind":kind,"center":p,"size":size})
func roof(p:Vector3,size:Vector3,color:Color) -> void:
	# Shared legacy roofs are double-sided; orient their bake normals outward.
	var first:int=builder.indices.size();builder.roof(p,size,color)
	for i in range(first,builder.indices.size(),3):
		var previous:int=builder.indices[i+1];builder.indices[i+1]=builder.indices[i+2];builder.indices[i+2]=previous
func building(p: Vector3,size: Vector2,floors: int,color: Color,role: String) -> void:
	var w:=size.x;var d:=size.y;var h:=STOREY*floors
	if level==2:
		box(p+Vector3(0,h/2,0),Vector3(w,h,d),color);return
	# Entrance lanes are painted into the terrain atlas and stop at road edges.
	if level==0:buildings.append({"kind":kind,"center":p,"size":size,"floors":floors,"role":role,"door_width":DOOR,"door_height":CLEAR_HEIGHT,"entries":[p+Vector3(0,.13,d/2+.8),p+Vector3(0,.13,-d/2-.8)]})
	for floor_index in floors+1:
		var y:=floor_index*STOREY
		# An actual stair opening with 2.5 m width and 9 m length.
		if floor_index>0 and floor_index<floors:
			box(p+Vector3(-1.5,y,0),Vector3(w-3,.20,d),Color(.51,.50,.43))
			box(p+Vector3(w/2-1.5,y,4.5),Vector3(3,.20,d-9),Color(.51,.50,.43))
		else:box(p+Vector3(0,y,0),Vector3(w,.20,d),Color(.51,.50,.43))
	for f in floors:
		var y:=f*STOREY+.1
		for side in [-1.0,1.0]:
			# Two opposite, unobstructed doors. Upper windows have open apertures.
			for sign in [-1.0,1.0]:
				box(p+Vector3(sign*(w+DOOR)/4,y+1.55,side*d/2),Vector3((w-DOOR)/2,3.1,WALL),color)
			box(p+Vector3(0,y+2.8,side*d/2),Vector3(DOOR,.6,WALL),color)
			if f>0:box(p+Vector3(0,y+.45,side*d/2),Vector3(DOOR,.9,WALL),color)
			# Side walls with real 1.6 m windows, never painted on solid boxes.
			box(p+Vector3(side*w/2,y+.45,0),Vector3(WALL,.9,d),color)
			box(p+Vector3(side*w/2,y+2.75,0),Vector3(WALL,.7,d),color)
			for z in range(0,int(d/3)):
				box(p+Vector3(side*w/2,y+1.65,-d/2+1.5+z*3),Vector3(WALL,1.5,1.4),color)
		# Split interior: cross wall has a two-metre opening on the axial route.
		if level==0:
			for sign in [-1.0,1.0]:
				var span: float=(w-2.4)/2-(3.0 if sign>0 and floors>1 else 0.0)
				box(p+Vector3(sign*(1.2+span/2),y+1.4,1),Vector3(span,2.8,.16),color.darkened(.1))
			# Human-scale furnishing stays off the main aisle and staircase.
			box(p+Vector3(-w*.28,y+.4,-d*.25),Vector3(2.1,.8,.8),Color(.30,.25,.18))
			box(p+Vector3(-w*.28,y+.8,d*.27),Vector3(1.2,1.6,.5),Color(.36,.39,.35))
			if role in ["house","barracks"]:
				box(p+Vector3(-w*.28,y+.23,d*.25-2),Vector3(1,.46,2),Color(.38,.45,.37))
				box(p+Vector3(-w*.28,y+.49,d*.25-2.6),Vector3(.85,.12,.6),Color(.77,.75,.64))
			elif role in ["factory main hall","workshop","hangar"]:
				box(p+Vector3(-w*.28,y+.65,d*.25-3),Vector3(2.2,1.3,1.5),Color(.30,.41,.39))
				box(p+Vector3(-w*.28,y+1.5,d*.25-3),Vector3(.65,.4,.55),Color(.63,.54,.25))
			elif role=="warehouse":
				for shelf in 3:
					box(p+Vector3(-w*.28,y+.25+shelf*.8,d*.25-3),Vector3(3,.12,1),Color(.38,.40,.38))
					box(p+Vector3(-w*.28,y+.55+shelf*.8,d*.25-3),Vector3(1.4,.48,.8),Color(.61,.49,.32))
		if f<floors-1:
			for step in 16:
				box(p+Vector3(w/2-1.5,y+(step+1)*.2-.1,-d/2+.5+step*.5),Vector3(2.4,.2,.52),Color(.55,.54,.47))
			box(p+Vector3(w/2-1.5,y+3.1,-d/2+8.6),Vector3(2.4,.2,1.4),Color(.55,.54,.47))
	# Pitched roofs are retained at near and middle detail.
	if role!="observatory":roof(p+Vector3(0,h+.11,0),Vector3(w+.5,1.3,d+.5),Color(.31,.34,.31) if kind else Color(.43,.25,.18))
func make(site_kind: int,lod: int) -> ArrayMesh:
	kind=site_kind;level=lod;builder=Builder.new()
	for spec in specifications():
		if spec.kind==kind:building(spec.center,spec.size,spec.floors,spec.color,spec.role)
	match kind:
		1:
			for x in [-45.0,-37.0]:box(Vector3(x,13,-47),Vector3(4,26,4),Color(.47,.32,.24))
			for x in [-34.0,-21.0]:box(Vector3(x,.65,24),Vector3(7,1.3,3),Color(.41,.44,.39))
		2:
			for x in [-45.0,-25.0,25.0,45.0]:
				# Walk-through shipping containers, 2.4 m internal headroom.
				var c:=Color(.24,.42,.46) if x<0 else Color(.59,.31,.22)
				box(Vector3(x,.1,24),Vector3(6,.2,12),c)
				box(Vector3(x,2.7,24),Vector3(6,.2,12),c)
				for side in [-1,1]:box(Vector3(x+side*2.9,1.4,24),Vector3(.2,2.6,12),c)
			box(Vector3(0,-.1,55),Vector3(144,.4,10),Color(.46,.47,.43))
			for x in [-49.0,49.0]:
				box(Vector3(x,-.15,91),Vector3(9,.5,66),Color(.49,.46,.38))
				box(Vector3(x,10,52),Vector3(2,20,2),Color(.75,.61,.25))
				box(Vector3(x,19,70),Vector3(2,2,40),Color(.75,.61,.25))
		3:
			fence(72)
			box(Vector3(58,7,-58),Vector3(1.5,14,1.5),Color(.44,.46,.40))
			box(Vector3(58,14,-58),Vector3(8,1,4),Color(.68,.69,.57))
		4:
			fence(48)
			# Radar pedestal occupies the fourth quadrant; both road axes stay open.
			box(Vector3(-23,.3,23),Vector3(16,.6,16),Color(.48,.49,.45))
			box(Vector3(-23,5,23),Vector3(3,10,3),Color(.40,.45,.41))
			box(Vector3(-23,10,23),Vector3(10,.5,7),Color(.61,.66,.60),false)
			# Solid bearing and yoke join the dish bowl at y=14 to its y=10 platform.
			box(Vector3(-23,12,23),Vector3(2.2,4,2.2),Color(.40,.45,.41))
			for side in [-1,1]:box(Vector3(-23+side*2.6,12.5,23),Vector3(.5,5,1),Color(.47,.52,.46))
			box(Vector3(-23,14,23),Vector3(6,.5,1),Color(.47,.52,.46),false)
			dish(Vector3(-23,14,23),9.0,16 if level==0 else 10 if level==1 else 6)
			box(Vector3(-23,17,23),Vector3(.35,5,.35),Color(.42,.48,.43),false)
			box(Vector3(-23,19.5,23),Vector3(1.1,.8,1.1),Color(.72,.76,.66),false)
			if level==0:
				for p in [Vector3(-28,0,-27),Vector3(18,0,18)]:
					for f in 2:
						box(p+Vector3(0,f*STOREY+1,0),Vector3(2,.8,.7),Color(.25,.32,.29))
						box(p+Vector3(0,f*STOREY+1.65,-.25),Vector3(1.7,.55,.18),Color(.22,.48,.42),false)
				for x in [19.0,25.0]:box(Vector3(x,1,-27),Vector3(2,2,3),Color(.33,.40,.36))
	Outer.decorate(self)
	Fixtures.decorate(self)
	return builder.finish()
func generate() -> Array:
	boxes.clear();render_boxes.clear();buildings.clear()
	var result: Array=[]
	for k in 11:
		result.append([])
		for lod in 3:result[k].append(make(k,lod))
	return result

func fence(radius: float) -> void:
	# Four 14 m gates, including in the silhouette LOD. Never seal a compound
	# with its bounding box: bounds are for culling only, individual walls collide.
	var half:=(radius-7.0)*.5
	for side in [-1,1]:
		for sign in [-1,1]:
			box(Vector3(side*radius,1.1,sign*(7+half)),Vector3(.3,2.2,half*2),Color(.41,.45,.36))
			box(Vector3(sign*(7+half),1.1,side*radius),Vector3(half*2,2.2,.3),Color(.41,.45,.36))
func dish(p: Vector3,radius: float,segments: int) -> void:
	# A shallow, open paraboloid: one opaque surface, no texture or transparency.
	for ring in 3:
		for sector in segments:
			var points: Array[Vector3]=[]
			for pair in [Vector2(ring,sector),Vector2(ring+1,sector),Vector2(ring+1,sector+1),Vector2(ring,sector+1)]:
				var r: float=radius*pair.x/3;var a: float=TAU*pair.y/segments
				points.append(p+Vector3(cos(a)*r,r*r*.035,sin(a)*r))
			var start: int=builder.vertices.size()
			for point in points:builder.vertices.append(point);builder.colors.append(Color(.72,.77,.70).darkened(ring*.045))
			builder.indices.append_array(PackedInt32Array([start,start+2,start+1,start,start+3,start+2]))

static func specifications() -> Array:
	var rows: Array=[]
	for x in [-43.0,-21.0,21.0,43.0]:
		for z in [-38.0,38.0]:rows.append(spec(0,Vector3(x,0,z),Vector2(13,16),2 if absf(x)>30 else 1,Color(.68,.61,.47),"house"))
	rows.append(spec(0,Vector3(-48,0,-17),Vector2(16,20),1,Color(.64,.53,.41),"market"))
	rows.append(spec(0,Vector3(48,0,17),Vector2(16,20),2,Color(.58,.65,.61),"town hall"))
	rows.append(spec(1,Vector3(24,0,-22),Vector2(30,28),3,Color(.55,.38,.28),"factory main hall"))
	rows.append(spec(1,Vector3(-24,0,-22),Vector2(24,28),2,Color(.53,.42,.32),"workshop"))
	rows.append(spec(1,Vector3(26,0,25),Vector2(24,22),1,Color(.53,.55,.50),"dispatch"))
	for x in [-38.0,38.0]:rows.append(spec(2,Vector3(x,0,-35),Vector2(27,26),2,Color(.62,.64,.59),"warehouse"))
	for x in [-42.0,-21.0,21.0,42.0]:rows.append(spec(3,Vector3(x,0,-40),Vector2(15,22),1,Color(.44,.49,.36),"barracks"))
	for x in [-37.0,37.0]:rows.append(spec(3,Vector3(x,0,24),Vector2(32,30),2,Color(.43,.48,.38),"hangar"))
	rows.append(spec(4,Vector3(-23,0,-23),Vector2(20,22),2,Color(.55,.60,.50),"radar control"))
	rows.append(spec(4,Vector3(23,0,-23),Vector2(18,20),1,Color(.43,.49,.40),"generator house"))
	rows.append(spec(4,Vector3(23,0,23),Vector2(20,22),2,Color(.53,.58,.51),"communications"))
	rows.append_array(Outer.specifications())
	return rows
static func spec(k: int,p: Vector3,size: Vector2,floors: int,color: Color,role: String) -> Dictionary:
	return {"kind":k,"center":p,"size":size,"floors":floors,"color":color,"role":role}
