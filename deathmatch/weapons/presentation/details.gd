extends RefCounted
## Shared 2000-era surface treatment and batched, weapon-specific working details.
const Geometry=preload("res://deathmatch/weapons/presentation/geometry.gd")
const Action=preload("res://deathmatch/weapons/presentation/mechanism.gd")
const ATLAS="res://deathmatch/weapons/presentation/finish.png"
static var materials: Dictionary={}
static var finished_materials: Dictionary={}
static var finished_meshes: Dictionary={}
static var decorations: Dictionary={}
static var finish_texture: Texture2D
static var detail_mask: Texture2D
static func palette(rules: String) -> Array:
	if materials.has(rules):return materials[rules]
	if not finish_texture:finish_texture=load(ATLAS)
	var accent: Color={"doom":Color("8cc88d"),"quake":Color("c9a16b"),"ut99":Color("b6c9d6"),"cs16":Color("b7c0c8"),"tribes":Color("91ada8")}.get(rules,Color("b1a68c"))
	var result: Array=[]
	for i in 6:
		var mat:=StandardMaterial3D.new();mat.resource_name="Weapon detail "+str(i)
		mat.roughness=.62 if i!=1 else .38;mat.metallic=.45 if i in [0,1,3] else 0.0
		if i<4:
			mat.albedo_texture=finish_texture;mat.uv1_scale=Vector3(.47,.47,1);mat.uv1_offset=Vector3(.015+(i%2)*.5,.015+(i/2)*.5,0)
			mat.albedo_color=accent if i==0 else Color.WHITE
		elif i==4:mat.albedo_color=Color.WHITE;mat.emission_enabled=true;mat.emission=Color("8ddaff");mat.emission_energy_multiplier=.6
		else:mat.albedo_color=Color("0e141a");mat.roughness=.92
		mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		result.append(mat)
	materials[rules]=result;return result
static func finish(root: Node3D,rules: String):
	palette(rules)
	if not detail_mask:
		var grad:=Gradient.new();grad.colors=PackedColorArray([Color(.28,.28,.28),Color(.28,.28,.28)])
		var mask:=GradientTexture1D.new();mask.gradient=grad;mask.width=4;detail_mask=mask
	for node in root.find_children("*","MeshInstance3D",true,false):
		if not node.mesh:continue
		var original_mesh: Mesh=node.mesh
		if not finished_meshes.has(original_mesh):
			var copy:=ArrayMesh.new();var bounds:=original_mesh.get_aabb()
			for s in original_mesh.get_surface_count():
				var arrays: Array=original_mesh.surface_get_arrays(s)
				var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var uv2:=PackedVector2Array();uv2.resize(positions.size())
				for j in positions.size():
					var n: Vector3=normals[j].abs() if normals.size()>j else Vector3.UP
					var a:=2 if n.x>n.y and n.x>n.z else 0;var b:=2 if n.y>=n.x and n.y>n.z else 1
					uv2[j]=Vector2((positions[j][a]-bounds.position[a])/maxf(.001,bounds.size[a]),(positions[j][b]-bounds.position[b])/maxf(.001,bounds.size[b]))
				arrays[Mesh.ARRAY_TEX_UV2]=uv2;copy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);copy.surface_set_material(s,original_mesh.surface_get_material(s))
			finished_meshes[original_mesh]=copy
		var active: Array=[]
		for s in original_mesh.get_surface_count():active.append(node.get_active_material(s))
		node.mesh=finished_meshes[original_mesh]
		for s in active.size():
			var source=active[s]
			if not source is StandardMaterial3D:continue
			if not finished_materials.has(source):
				var mat: StandardMaterial3D=source.duplicate()
				mat.roughness=clampf(mat.roughness,.45,.82)
				if not mat.emission_enabled:
					mat.detail_enabled=true;mat.detail_albedo=finish_texture;mat.detail_mask=detail_mask
					mat.detail_uv_layer=BaseMaterial3D.DETAIL_UV_2;mat.detail_blend_mode=BaseMaterial3D.BLEND_MODE_MIX
					mat.uv2_scale=Vector3(.46,.46,1);mat.uv2_offset=Vector3(.52,.02,0)
				if not mat.albedo_texture:
					mat.albedo_texture=finish_texture;mat.uv1_scale=Vector3(.46,.46,1);mat.uv1_offset=Vector3(.52,.02,0)
					# Small indicator areas emit; structural receiver panels do not.
					if mat.emission_energy_multiplier<.4:mat.emission_enabled=false
				finished_materials[source]=mat
			node.set_surface_override_material(s,finished_materials[source])
			node.material_override=null
static func apply(root: Node3D,slot: int,rules: String):
	if rules=="sentry":
		# The authored model already separates the six barrels and front collar.
		# Rotate those real parts around their common bore axis.
		var source:=root.get_node("sentry_gatling")
		var cluster:=moving(source,"RotatingBarrelCluster",Vector3.ZERO,"spin",Vector3(0,0,1))
		for part in source.get_children():
			if str(part.name).begins_with("Cylinder_"):part.owner=null;part.reparent(cluster,false)
	if root.get_meta("authored_fidelity",false):
		# Geometry, UV wear and moving pieces are authored offline. Do not cover
		# them with the old repeated receiver plates or silver detail projection.
		var details:=Node3D.new();details.name="PresentationDetails";root.add_child(details)
		root.set_meta("presentation",rules+":"+str(slot));return
	finish(root,rules)
	var key:=rules+":"+str(slot)
	if not decorations.has(key):
		var detail:=build(slot,rules);own(detail,detail)
		var packed:=PackedScene.new();packed.pack(detail);decorations[key]=packed;detail.free()
	root.add_child(decorations[key].instantiate())
	root.set_meta("presentation",key)
static func attach(root: Node3D,slot: int,rules: String):
	var action:=Action.new();root.add_child(action);action.setup(root,slot,rules)
static func own(node: Node,root: Node):
	for child in node.get_children():child.owner=root;own(child,root)
static func moving(root: Node3D,label: String,origin: Vector3,motion: String,amount: Vector3) -> Node3D:
	var node:=Node3D.new();node.name=label;node.position=origin;node.set_meta("motion",motion);node.set_meta("amount",amount);root.add_child(node);return node
static func screws(g,at: Vector3,width: float,span: float):
	for side in [-1,1]:
		for z in [-span*.5,span*.5]:
			g.tube(at+Vector3(side*width,0,z),.010,.008,1,0,Basis(Vector3.UP,PI/2),8)
			g.box(at+Vector3(side*(width+.005),0,z),Vector3(.002,.003,.010),5,.0003)
static func vents(g,at: Vector3,count: int,span: float,width: float):
	for i in count:
		g.box(at+Vector3(0,0,(i-float(count-1)*.5)*span),Vector3(width,.008,span*.48),5,.002)
static func rotor(root: Node3D,pal: Array,at: Vector3,radius: float,length: float,count: int=6):
	var group:=moving(root,"RotaryAssembly",at,"spin",Vector3(0,0,1));var g:=Geometry.new(pal)
	for i in count:
		var p:=Vector2.from_angle(TAU*i/count)*radius*.68
		g.tube(Vector3(p.x,p.y,0),radius*.21,length,1,radius*.13)
	for z in [-length*.38,length*.38]:g.tube(Vector3(0,0,z),radius,.025,0,radius*.8)
	g.node(group,"BarrelsAndRetainingRings")
static func energy(root: Node3D,pal: Array,at: Vector3,color: Color,length: float=.24):
	var g:=Geometry.new(pal)
	for side in [-1,1]:
		g.box(at+Vector3(side*.012,0,0),Vector3(.012,.022,length),4,.003)
	var mesh:=g.node(root,"EnergyWindows");mesh.set_meta("emission_color",color)
static func build(slot: int,rules: String) -> Node3D:
	var root:=Node3D.new();root.name="PresentationDetails";var pal:=palette(rules);var g:=Geometry.new(pal)
	if rules=="cs16":
		cs_detail(root,g,pal,slot)
	elif rules=="tribes":
		tribes_detail(root,g,pal,slot)
	elif rules in ["sentry","tf_sniper","tf_flame"] or rules=="ut99" and slot==9:
		special_detail(root,g,pal,"tf_sniper" if rules=="ut99" else rules)
	elif rules=="doom" and slot==0:
		# The live fists use the animated tracked/avatar hands.
		pass
	else:arena_detail(root,g,pal,slot,rules)
	if not g.surfaces.is_empty():g.node(root,"BatchedReceiverDetails")
	return root
static func cs_detail(root,g,pal,slot: int):
	if slot==0:
		for z in [-.016,.006,.028]:g.tube(Vector3(0,0,z),.041,.006,1,0)
		g.box(Vector3(0,.029,-.06),Vector3(.065,.011,.014),1,.002);return
	var pistol: bool=slot in [1,2,10]
	var width:=.044 if pistol else .058 if slot!=8 else .077
	var y:=.045 if pistol else .07
	var z: float=.022 if pistol else -.16
	for side in [-1,1]:
		g.box(Vector3(side*width,y,z),Vector3(.008,.032,.06),0,.003)
		screws(g,Vector3(0,y,z),width+.004,.043)
		g.tube(Vector3(side*(width+.003),y+.027,z+.012),.009,.009,1,0,Basis(Vector3.UP,PI/2),8)
	if not pistol and slot!=11:
		vents(g,Vector3(0,.106,-.43),5,.024,.075)
	if slot==9:
		g.tube(Vector3(.059,.244,-.21),.025,.026,0,0,Basis(Vector3.UP,PI/2))
		g.tube(Vector3(0,.301,-.21),.023,.022,0,0,Basis(Vector3.RIGHT,PI/2))
	if slot==8:
		for side in [-1,1]:g.cable([Vector3(side*.06,.12,-.62),Vector3(side*.095,.04,-.64),Vector3(side*.11,-.04,-.51)],.009,1)
	# Actual Slide/Bolt/Pump/FeedCover remain driven by ChamberAction.
static func tribes_detail(root,g,pal,slot: int):
	if slot in [9,10]:
		var y:=.025 if slot==9 else .008
		g.tube(Vector3(0,y,0),.058 if slot==9 else .10,.012,1,.044 if slot==9 else .084,Basis(Vector3.RIGHT,PI/2))
		g.cable([Vector3(.025,y+.015,0),Vector3(.045,y+.035,0),Vector3(.065,y+.015,0)],.005,1)
		energy(root,pal,Vector3(0,y+.025,-.02),Color("df754d"),.025);return
	for side in [-1,1]:
		g.box(Vector3(side*.108,.145,-.14),Vector3(.018,.087,.20),0,.011)
		g.box(Vector3(side*.12,.145,-.14),Vector3(.005,.046,.14),3,.004)
		screws(g,Vector3(0,.145,-.14),.126,.155)
	g.box(Vector3(0,.265,-.18),Vector3(.085,.035,.14),0,.008)
	vents(g,Vector3(0,.286,-.18),5,.023,.061)
	g.cable([Vector3(.10,.11,-.09),Vector3(.15,.06,-.18),Vector3(.15,.06,-.28),Vector3(.1,.12,-.36)],.009)
	match slot:
		2:rotor(root,pal,Vector3(0,.16,-.61),.132,.32)
		3:
			var rim:=moving(root,"MagneticInductor",Vector3(0,.255,-.36),"spin",Vector3(0,1,0));var ring:=Geometry.new(pal)
			for i in 8:
				var v:=Vector2.from_angle(TAU*i/8)*.204;ring.box(Vector3(v.x,.015,v.y),Vector3(.035,.024,.045),1,.006,Basis(Vector3.UP,-TAU*i/8))
			ring.node(rim,"InductorSegments");energy(root,pal,Vector3(0,.287,-.15),Color("62aaff"),.12)
		4,7:
			var breech:=moving(root,"LauncherBreech",Vector3(.125,.17,-.20),"slide",Vector3(0,0,.055));var moving_g:=Geometry.new(pal)
			moving_g.box(Vector3.ZERO,Vector3(.028,.095,.15),1,.012);moving_g.box(Vector3(.021,0,.015),Vector3(.032,.022,.037),0,.005);moving_g.node(breech,"BreechAndLatch")
			if slot==7:energy(root,pal,Vector3(0,.335,-.45),Color("8ee575"),.23)
		_:
			var colors:={0:Color("f57461"),1:Color("ffb74f"),5:Color("e96369"),6:Color("82b8ff"),8:Color("65dea8"),11:Color("ef7763")}
			energy(root,pal,Vector3(0,.291,-.18),colors.get(slot,Color("8adaf1")),.115)
			var sink:=moving(root,"CoolingVanes",Vector3(0,.21,-.34),"vent",Vector3(0,.014,0));var blades:=Geometry.new(pal)
			for side in [-1,1]:
				for z in [-.045,0,.045]:blades.box(Vector3(side*.114,0,z),Vector3(.018,.087,.021),1,.003)
			blades.node(sink,"HeatSinkFins")
static func special_detail(root,g,pal,rules: String):
	if rules=="sentry":
		for z in [.10,.18,.26]:g.box(Vector3(.193,.045,z),Vector3(.012,.08,.04),0,.004)
	elif rules=="tf_sniper":
		var bolt:=moving(root,"SniperBolt",Vector3(.062,.10,-.06),"bolt",Vector3(0,0,.10));var b:=Geometry.new(pal)
		b.tube(Vector3.ZERO,.016,.12,1);b.cable([Vector3.ZERO,Vector3(.055,-.028,.04)],.013,1);b.node(bolt,"BoltHandle")
	else:
		g.tube(Vector3(.14,.06,-.15),.042,.035,3,0,Basis(Vector3.UP,PI/2))
		g.cable([Vector3(.10,-.07,-.13),Vector3(.16,-.13,-.25),Vector3(.15,-.11,-.47),Vector3(.07,.03,-.6)],.012,2)
		energy(root,pal,Vector3(0,.04,-.74),Color("ff9a45"),.06)
	for side in [-1,1]:g.box(Vector3(side*.078,.08,-.16),Vector3(.02,.07,.16),0,.007)
	screws(g,Vector3(0,.08,-.16),.092,.12)
static func arena_detail(root,g,pal,slot: int,rules: String):
	var melee: bool=rules=="quake" and slot<2 or rules=="ut99" and slot==0 or rules=="doom" and slot==1
	if melee:
		if rules=="quake":
			for y in [.02,.055,.09]:g.tube(Vector3(0,y,-.05),.034,.022,2,0,Basis(Vector3.RIGHT,PI/2),8)
			g.box(Vector3(0,.32,-.39),Vector3(.045,.033,.08),1,.007)
		elif rules=="ut99":
			for side in [-1,1]:g.cable([Vector3(side*.08,.025,-.10),Vector3(side*.13,.015,-.23),Vector3(side*.09,.02,-.40)],.010,3)
			energy(root,pal,Vector3(.06,.055,-.20),Color("eaa762"),.10)
		else:
			var wheel:=moving(root,"SawDrive",Vector3(.027,0,-.12),"spin",Vector3(1,0,0));var w:=Geometry.new(pal)
			w.tube(Vector3.ZERO,.057,.025,1,.024,Basis(Vector3.UP,PI/2));w.box(Vector3(.016,0,0),Vector3(.012,.02,.09),3,.003);w.node(wheel,"DriveSprocket")
			g.box(Vector3(0,.045,-.10),Vector3(.07,.042,.11),0,.008)
		return
	var pistol: bool=slot==2 and rules in ["doom","ut99"]
	var compact: bool=rules=="ut99" and slot==11
	var width:=.08 if pistol or compact else .12
	var center:=Vector3(0,.07,-.19 if pistol or compact else -.28)
	for side in [-1,1]:
		g.box(center+Vector3(side*width,0,0),Vector3(.026,.093,.17 if compact else .23),0,.008)
		g.box(center+Vector3(side*(width+.016),-.012,0),Vector3(.005,.038,.12),3 if rules=="quake" else 1,.004)
		screws(g,center,width+.021,.15)
	if not compact:
		vents(g,center+Vector3(0,.062,0),5,.031,width*1.35)
		g.box(center+Vector3(0,.037,.15),Vector3(.14,.045,.036),0,.005)
	var rotary: bool=rules=="doom" and slot==5 or rules=="ut99" and slot==5 or rules=="quake" and slot==7
	var shotgun: bool=rules=="doom" and slot in [3,4] or rules=="quake" and slot in [2,3] or rules=="ut99" and slot==4
	var launcher: bool=rules=="doom" and slot==6 or rules=="quake" and slot in [4,6] or rules=="ut99" and slot in [6,8]
	if rotary:rotor(root,pal,Vector3(0,.05,-.60),.112,.43,4 if rules=="quake" else 6)
	elif pistol:
		var slide:=moving(root,"ReceiverSlide",Vector3(0,.12,-.20),"slide",Vector3(0,0,.055));var s:=Geometry.new(pal)
		s.box(Vector3.ZERO,Vector3(.14,.059,.30),0,.009)
		for side in [-1,1]:
			for z in [.06,.082,.104]:s.box(Vector3(side*.071,0,z),Vector3(.006,.031,.005),1,.001)
		s.node(slide,"SerratedSlide")
	elif shotgun:
		var pump:=moving(root,"ReciprocatingForeEnd",Vector3(0,.02,-.51),"pump",Vector3(0,0,.095));var p:=Geometry.new(pal)
		p.tube(Vector3.ZERO,.087,.19,2,.067)
		for z in [-.07,-.035,0,.035,.07]:p.tube(Vector3(0,0,z),.093,.011,0,.08)
		p.node(pump,"RibbedForeEnd")
		g.tube(Vector3(0,.012,-.77),.067,.07,1,.045)
	elif launcher:
		var door:=moving(root,"LoadingGate",Vector3(width+.035,.05,-.18),"hinge",Vector3(0,0,-.65));var d:=Geometry.new(pal)
		d.box(Vector3(0,0,-.055),Vector3(.018,.12,.14),0,.009);d.box(Vector3(.013,0,-.025),Vector3(.016,.025,.055),1,.004);d.node(door,"BreechCover")
		for side in [-1,1]:g.tube(Vector3(side*width,-.03,-.45),.024,.27,1,.015)
	elif rules=="quake" and slot==5:
		for side in [-1,1]:
			var nail:=moving(root,"NailPiston"+str(side),Vector3(side*.06,.05,-.62),"slide",Vector3(0,0,.06*side));var n:=Geometry.new(pal)
			n.tube(Vector3.ZERO,.036,.25,1,.021);n.node(nail,"Driver")
	elif compact:
		# The user's flared disc and raised core are retained exactly as authored.
		g.box(Vector3(0,.092,-.08),Vector3(.056,.020,.07),1,.004)
		energy(root,pal,Vector3(0,.11,-.08),Color("8db7ff"),.043)
	elif rules=="ut99" and slot==10:
		var feed:=moving(root,"DiscFeed",Vector3(.15,.13,-.2),"slide",Vector3(0,0,.05));var f:=Geometry.new(pal)
		f.box(Vector3.ZERO,Vector3(.036,.05,.22),1,.006);f.node(feed,"FeedPawl")
	else:
		var colors:={"doom":Color("64c9ec"),"quake":Color("94baff"),"ut99":Color("99dfbe")}
		var color: Color=Color("92e450") if rules=="doom" and slot==8 or rules=="ut99" and slot==1 else Color("bf89f6") if rules=="ut99" and slot==3 else colors[rules]
		energy(root,pal,center+Vector3(0,.088,0),color,.21)
		var vane:=moving(root,"ReactorShroud",center+Vector3(0,.05,-.1),"vent",Vector3(0,.026,0));var v:=Geometry.new(pal)
		for side in [-1,1]:
			v.box(Vector3(side*(width+.03),0,0),Vector3(.025,.11,.21),0,.008)
			g.cable([center+Vector3(side*width,0,.1),center+Vector3(side*(width+.06),-.03,0),center+Vector3(side*width,0,-.17)],.01,3)
		v.node(vane,"OpeningCoolingPanels")
