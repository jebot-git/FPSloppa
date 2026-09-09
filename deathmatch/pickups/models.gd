extends RefCounted
## Authored low-poly supply props. One cached vertex-colour mesh per variant keeps
## the additional silhouette/detail inexpensive in stereo, without runtime CSG.
const STEEL=Color("626c69")
const EDGE=Color("a1a99c")
const DARK=Color("252f2b")
const OLIVE=Color("58634b")
const BRASS=Color("b79a57")
const RED=Color("994f3e")
const WHITE=Color("d0c8ad")
const BLUE=Color("548794")
static var cache: Dictionary={}
var surface:=SurfaceTool.new()
func _init():surface.begin(Mesh.PRIMITIVE_TRIANGLES)
static func create(kind: String,item: int) -> Node3D:
	var key:=kind+str(item)
	if not cache.has(key):
		var builder=new()
		match kind:
			"health":builder.medkit(item==100)
			"armor":builder.armour(item)
			"ammo":builder.ammunition(item)
			_:builder.bonus(item)
		var mesh: ArrayMesh=builder.surface.commit()
		var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.roughness=.68;material.metallic=.22
		mesh.surface_set_material(0,material)
		cache[key]=mesh
	var node:=MeshInstance3D.new();node.mesh=cache[key];node.name="SupplyModel"
	node.set_meta("pickup_kind",kind);node.set_meta("pickup_item",item)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
func tri(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	# Godot's front faces use clockwise winding; store outward vertex normals.
	var normal: Vector3=(c-a).cross(b-a).normalized()
	for point in [a,b,c]:surface.set_normal(normal);surface.set_color(color);surface.add_vertex(point)
func quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color) -> void:
	tri(a,b,c,color);tri(a,c,d,color)
func block(pos: Vector3,size: Vector3,color: Color,bevel: float=.012,rotation: Vector3=Vector3.ZERO) -> void:
	var hx:=size.x*.5;var hy:=size.y*.5;var hz:=size.z*.5
	var r:=minf(bevel,minf(hx,minf(hy,hz))*.45)
	var rotation_basis:=Basis.from_euler(rotation)
	var rings: Array=[]
	for ring in range(4):
		var inset:=r if ring in [0,3] else 0.0
		var x:=hx-inset;var y:=hy-inset
		var z:float=[-hz,-hz+r,hz-r,hz][ring]
		var outline:=[Vector2(-x+r,-y),Vector2(x-r,-y),Vector2(x,-y+r),Vector2(x,y-r),Vector2(x-r,y),Vector2(-x+r,y),Vector2(-x,y-r),Vector2(-x,-y+r)]
		var points: Array[Vector3]=[]
		for point in outline:points.append(pos+rotation_basis*Vector3(point.x,point.y,z))
		rings.append(points)
	for i in range(8):
		var next: int=(i+1)%8
		tri(pos+rotation_basis*Vector3(0,0,-hz),rings[0][i],rings[0][next],color)
		tri(pos+rotation_basis*Vector3(0,0,hz),rings[3][next],rings[3][i],color)
		for ring in range(3):quad(rings[ring][i],rings[ring+1][i],rings[ring+1][next],rings[ring][next],color.lightened(.06) if ring!=1 else color)
func cylinder(pos: Vector3,radius: float,height: float,color: Color,top_radius: float=-1) -> void:
	if top_radius<0:top_radius=radius
	for i in range(10):
		var a:=TAU*i/10;var b:=TAU*(i+1)/10
		var p:=pos+Vector3(cos(a)*radius,-height*.5,sin(a)*radius)
		var q:=pos+Vector3(cos(b)*radius,-height*.5,sin(b)*radius)
		var r:=pos+Vector3(cos(b)*top_radius,height*.5,sin(b)*top_radius)
		var s:=pos+Vector3(cos(a)*top_radius,height*.5,sin(a)*top_radius)
		quad(p,q,r,s,color)
		tri(pos+Vector3.UP*height*.5,s,r,color.lightened(.08))
		tri(pos-Vector3.UP*height*.5,q,p,color.darkened(.08))
func seams(pos: Vector3,width: float,color: Color=EDGE) -> void:
	for x in [-width*.38,width*.38]:block(pos+Vector3(x,0,0),Vector3(.024,.065,.016),color,.004)
func medkit(mega: bool=false) -> void:
	var paint:=Color("247c9b") if mega else WHITE
	var cross:=Color("affbff") if mega else RED
	block(Vector3.ZERO,Vector3(.53,.34,.29),DARK,.035)
	block(Vector3(0,0,-.035),Vector3(.50,.31,.25),paint,.027)
	block(Vector3(0,0,-.169),Vector3(.075,.20,.014),cross,.005)
	block(Vector3(0,0,-.173),Vector3(.21,.072,.014),cross,.005)
	for x in [-.175,.175]:
		block(Vector3(x,0,0),Vector3(.040,.345,.294),OLIVE,.008)
		block(Vector3(x,.075,-.157),Vector3(.056,.05,.025),EDGE,.005)
		block(Vector3(x,-.065,-.16),Vector3(.035,.055,.008),DARK,.002)
	for x in [-.1,.1]:block(Vector3(x,.218,.018),Vector3(.032,.10,.043),STEEL,.008)
	block(Vector3(0,.26,.018),Vector3(.225,.038,.05),DARK,.01)
	for x in [-.205,.205]:block(Vector3(x,-.13,-.167),Vector3(.052,.015,.007),EDGE,.002)
func armour(tier: int) -> void:
	var paint:=OLIVE if tier<2 else Color("315da2")
	if tier==2:
		for side in [-1,1]:
			block(Vector3(side*.10,.08,-.16),Vector3(.13,.025,.022),Color("e4bb59"),.005,Vector3(0,0,side*.35))
			block(Vector3(side*.10,.035,-.16),Vector3(.13,.025,.022),Color("e4bb59"),.005,Vector3(0,0,side*.35))
	block(Vector3(0,-.02,.025),Vector3(.42,.48,.18),DARK,.035)
	for side in [-1,1]:
		block(Vector3(side*.13,.12,-.052),Vector3(.245,.255,.16),paint,.026,Vector3(0,side*-.13,side*-.07))
		block(Vector3(side*.235,.205,.005),Vector3(.12,.115,.20),STEEL,.018,Vector3(0,0,side*-.30))
		block(Vector3(side*.13,.272,.055),Vector3(.065,.10,.14),OLIVE,.012)
		block(Vector3(side*.157,-.14,-.08),Vector3(.104,.105,.045),paint,.016)
	for i in range(3):block(Vector3(0,-.05-i*.064,-.102),Vector3(.255,.054,.058),paint,.012)
	block(Vector3(0,-.235,0),Vector3(.44,.055,.215),OLIVE,.012)
	block(Vector3(0,-.235,-.125),Vector3(.083,.062,.025),EDGE,.006)
	block(Vector3(0,.13,-.147),Vector3(.028,.072,.009),WHITE,.003)
	block(Vector3(0,.13,-.15),Vector3(.070,.024,.009),WHITE,.003)
func ammunition(kind: int) -> void:
	if kind==0:
		block(Vector3(0,-.10,0),Vector3(.43,.22,.28),OLIVE,.024)
		block(Vector3(0,.015,0),Vector3(.46,.038,.30),STEEL,.009)
		for x in [-.14,0,.14]:
			for z in [-.07,.07]:
				cylinder(Vector3(x,.065,z),.036,.17,BRASS)
				cylinder(Vector3(x,.18,z),.035,.075,EDGE,.006)
		seams(Vector3(0,-.06,-.152),.43)
		block(Vector3(0,-.12,-.151),Vector3(.12,.043,.014),WHITE,.004)
	elif kind==1:
		block(Vector3(0,-.11,0),Vector3(.42,.12,.24),DARK,.015)
		for x in [-.14,0,.14]:
			for z in [-.065,.065]:
				cylinder(Vector3(x,.02,z),.05,.27,RED)
				cylinder(Vector3(x,-.085,z),.055,.065,BRASS)
		block(Vector3(0,.045,-.13),Vector3(.43,.035,.015),OLIVE,.004)
	elif kind==2:
		block(Vector3(0,-.18,0),Vector3(.46,.07,.25),DARK,.012)
		for x in [-.15,0,.15]:
			cylinder(Vector3(x,0,0),.06,.32,OLIVE)
			cylinder(Vector3(x,.16,0),.061,.045,RED)
			cylinder(Vector3(x,.245,0),.06,.13,STEEL,0.0)
			for offset in [-.065,.065]:block(Vector3(x+offset,-.09,0),Vector3(.027,.13,.08),EDGE,.005)
	else:
		block(Vector3.ZERO,Vector3(.45,.30,.25),DARK,.028)
		for x in [-.16,.16]:block(Vector3(x,0,0),Vector3(.095,.33,.28),STEEL,.019)
		block(Vector3(0,0,-.137),Vector3(.22,.20,.024),BLUE,.012)
		for y in [-.065,0,.065]:block(Vector3(0,y,-.155),Vector3(.175,.031,.015),Color("8ac0b9"),.004)
		for x in [-.11,0,.11]:cylinder(Vector3(x,.18,0),.023,.055,BRASS)
		for y in [-.09,-.035,.02,.075]:block(Vector3(.216,y,0),Vector3(.018,.014,.14),DARK,.002)
func bonus(item: int) -> void:
	if item==0:
		cylinder(Vector3.ZERO,.105,.25,BLUE)
		cylinder(Vector3(0,.145,0),.08,.06,EDGE)
		block(Vector3(0,0,-.108),Vector3(.035,.12,.012),WHITE,.003)
		block(Vector3(0,0,-.112),Vector3(.105,.035,.012),WHITE,.003)
	else:
		block(Vector3.ZERO,Vector3(.22,.23,.085),OLIVE,.024)
		block(Vector3(0,0,-.047),Vector3(.12,.11,.018),EDGE,.015)
