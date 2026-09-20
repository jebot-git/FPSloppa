extends Node3D
## Original low-poly twin-thruster backpack. Shared static meshes, no realtime
## lights or particle emitters; exhaust costs one additional mesh per visible user.
static var shells: Array[ArrayMesh]=[]
static var plume: CylinderMesh
var exhaust: MeshInstance3D
static func box(st: SurfaceTool,at: Vector3,size: Vector3) -> void:
	var mesh:=BoxMesh.new();mesh.size=size;st.append_from(mesh,0,Transform3D(Basis.IDENTITY,at))
static func tube(st: SurfaceTool,at: Vector3,radius: float,height: float) -> void:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=8;mesh.rings=1
	st.append_from(mesh,0,Transform3D(Basis.IDENTITY,at))
static func build() -> void:
	if not shells.is_empty():return
	for part in 3:
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var mat:=StandardMaterial3D.new();mat.metallic=.6;mat.roughness=.6
		mat.albedo_color=[Color("52616b"),Color("202831"),Color("67d5ee")][part]
		if part==2:mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		st.set_material(mat)
		if part==0:
			box(st,Vector3(0,0,.06),Vector3(.25,.46,.20))
			for side in [-1,1]:
				tube(st,Vector3(side*.18,0,.04),.105,.48)
				box(st,Vector3(side*.27,.04,.035),Vector3(.04,.27,.18))
		elif part==1:
			box(st,Vector3(0,0,-.065),Vector3(.38,.40,.07))
			for side in [-1,1]:
				tube(st,Vector3(side*.18,-.265,.04),.083,.10)
				for y in [-.15,.15]:tube(st,Vector3(side*.18,y,.04),.114,.045)
			for y in [-.12,-.06,0,.06]:box(st,Vector3(0,y,.168),Vector3(.17,.024,.026))
		else:
			box(st,Vector3(0,.16,.168),Vector3(.16,.035,.025))
			for side in [-1,1]:tube(st,Vector3(side*.18,-.315,.04),.061,.018)
		shells.append(st.commit())
	plume=CylinderMesh.new();plume.top_radius=.06;plume.bottom_radius=.015;plume.height=.32;plume.radial_segments=8;plume.rings=1
func _init() -> void:
	name="CQJetpack";build()
	for mesh in shells:
		var node:=MeshInstance3D.new();node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("83e9ff");mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;st.set_material(mat)
	for side in [-1,1]:st.append_from(plume,0,Transform3D(Basis.IDENTITY,Vector3(side*.18,-.48,.04)))
	exhaust=MeshInstance3D.new();exhaust.mesh=st.commit();exhaust.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(exhaust);exhaust.hide()
func set_exhaust(active: bool) -> void:exhaust.visible=active
