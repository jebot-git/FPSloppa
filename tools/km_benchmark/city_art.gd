extends RefCounted
## Static meshes are merged per district/material. All movement is vertex shading.
const Presentation=preload("res://deathmatch/conquest/presentation.gd")
static func v(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
static func material(color: Color,glow: bool=true) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.8
	if glow:m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
static func add(parent: Node,child: Node,owner_: Node) -> void:parent.add_child(child);child.owner=owner_
static func box(size: Vector3) -> BoxMesh:
	var mesh:=BoxMesh.new();mesh.size=size;return mesh
static func ring(radius: float,thickness: float) -> TorusMesh:
	var mesh:=TorusMesh.new();mesh.inner_radius=maxf(.01,radius-thickness);mesh.outer_radius=radius;mesh.rings=32;mesh.ring_segments=6;return mesh
static func append(batches: Dictionary,key: String,mesh: Mesh,pos: Vector3,basis: Basis=Basis.IDENTITY) -> void:
	if not batches.has(key):
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);batches[key]=st
	batches[key].append_from(mesh,0,Transform3D(basis,pos))
static func label(parent: Node,owner_: Node,text: String,pos: Vector3,yaw: float,color: Color,size_: float) -> void:
	var node:=Label3D.new();node.text=text;node.font_size=64;node.pixel_size=size_/64;node.modulate=color;node.outline_size=6;node.no_depth_test=false;node.position=pos;node.rotation.y=yaw;add(parent,node,owner_)
static func district(parent: Node3D,owner_: Node,layout: Dictionary,zone: int) -> void:
	var art:=Node3D.new();art.name="CityArt";add(parent,art,owner_)
	var tint:=Color.html(layout.zones[zone].color);var batches: Dictionary={};var mats: Dictionary={"glow":material(tint*.8),"dark":material(Color(.06,.09,.13)),"foliage":material(Color(.12,.25,.21)),"steam":ShaderMaterial.new()}
	mats.steam.shader=preload("res://deathmatch/conquest/steam.gdshader")
	for kind in ["window","gothic"]:
		var m:=ShaderMaterial.new();m.shader=preload("res://deathmatch/conquest/window.gdshader");m.set_shader_parameter("tint",tint);m.set_shader_parameter("gothic",kind=="gothic");mats[kind]=m
	var steam_count:=0
	for row in layout.art:
		if int(row.zone)!=zone:continue
		var p:=v(row.position);var s:=v(row.size)
		match row.kind:
			"window":append(batches,"gothic" if row.get("gothic",false) else "window",box(s),p)
			"box":append(batches,"glow",box(s),p)
			"beacon":
				append(batches,"glow",box(s),p);append(batches,"glow",box(Vector3(s.y,.35,.35)),p)
			"ring","plaza":append(batches,"glow",ring(s.x*.5,.12 if row.kind=="plaza" else .18),p)
			"orbital":
				for angle in [0.0,PI/3,-PI/3]:append(batches,"glow",ring(s.x*.5,.18),p,Basis(Vector3.FORWARD,angle))
				var core:=SphereMesh.new();core.radius=s.x*.12;core.height=core.radius*2;core.radial_segments=12;core.rings=6;append(batches,"glow",core,p)
			"steam":
				if steam_count>=2:continue
				steam_count+=1;var mesh:=QuadMesh.new();mesh.size=Vector2(s.x,s.y);append(batches,"steam",mesh,p+Vector3.UP*s.y*.5)
			"garden":
				append(batches,"dark",box(Vector3(s.x,1.2,s.z)),p-Vector3.UP*1.5)
				for i in 5:
					var tree:=PrismMesh.new();tree.size=Vector3(2,4+i%2,2);append(batches,"foliage",tree,p+Vector3((i%3-1)*2,1,(i/3-.5)*2),Basis(Vector3.UP,i*.7))
			"data":
				append(batches,"dark",box(s),p)
				for i in 8:append(batches,"glow",box(Vector3(s.x+.12,.16,s.z+.12)),p+Vector3.UP*(i-3.5)*1.3)
	for key in batches:
		batches[key].set_material(mats[key]);var node:=MeshInstance3D.new();node.name=key;node.mesh=batches[key].commit();node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add(art,node,owner_)
	# Reuse the reviewed LibreQuake brazier fixtures beside each reliquary.
	var fixture: Mesh=preload("res://deathmatch/maps/librequake_props.gd").fixture("flame2")
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=fixture;multi.instance_count=4
	var c:=v(layout.zones[zone].center)
	for i in 4:multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*2.5),c+Vector3(-29 if i%2==0 else 29,1.1,-26 if i<2 else 26)))
	var fixtures:=MultiMeshInstance3D.new();fixtures.multimesh=multi;fixtures.name="Braziers";add(art,fixtures,owner_)
	for quadrant in 4:
		var side:=1.0 if quadrant<2 else -1.0
		var p:=c+Vector3(-72 if quadrant%2==0 else 72,7.8,(-70 if quadrant<2 else 70)+side*27.1)
		label(art,owner_,str(layout.zones[zone].name).to_upper(),p,0 if side>0 else PI,tint,.7)
	for row in layout.gates:
		if int(row.zone)!=zone:continue
		var p:=v(row.position);var n:=v(row.normal);var yaw:=atan2(n.x,n.z)
		var gate:=MeshInstance3D.new();gate.name="OpaqueGate_%02d"%int(row.neighbor);var quad:=QuadMesh.new();quad.size=Vector2(24,16);gate.mesh=quad
		var m:=ShaderMaterial.new();m.shader=preload("res://deathmatch/conquest/gate.gdshader");m.set_shader_parameter("tint",tint);gate.material_override=m;gate.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;gate.position=p;gate.rotation.y=yaw;add(art,gate,owner_)
		gate.set_meta("walkthrough",true);gate.set_meta("destination",int(row.neighbor))
		var occluder:=OccluderInstance3D.new();var bounds:=BoxOccluder3D.new();bounds.size=Vector3(23.96,15.96,.02);occluder.occluder=bounds;occluder.name="GateOccluder";add(gate,occluder,owner_)
		label(art,owner_,"%02d  /  %s"%[int(row.neighbor)+1,str(row.name).to_upper()],p+Vector3.UP*2+n*.035,yaw,tint,.7)
		label(art,owner_,"DISTRICT TRANSIT  •  WALK THROUGH",p-Vector3.UP*1.3+n*.035,yaw,Color(.55,.7,.8),.32)
static func apply(level: Node3D,layout: Dictionary) -> void:
	var root:=Node3D.new();root.name="CityPresentation";root.set_script(Presentation);add(level,root,level)
	for zone in 16:
		var node:=Node3D.new();node.name="Sector_%02d"%zone;add(root,node,level);district(node,level,layout,zone)
