extends Node3D
var utility_ref: WeakRef
var utility:
	get:return utility_ref.get_ref()
var game:
	get:return utility.game
var meshes: Dictionary={}
var smoke: Dictionary={}
var hands: Dictionary={}
var screen: ColorRect
var layer: CanvasLayer
var eye_quad: MeshInstance3D
var eye_material: ShaderMaterial
func setup(value):utility_ref=weakref(value);name="DEUtility"
static func held_pose(grip: Transform3D,left: bool) -> Transform3D:
	# Cylinder top follows the thumb; mirror the safety lever toward the palm.
	var basis:=Basis(Vector3.RIGHT,-PI/2)*Basis(Vector3.UP,0 if left else PI)
	return grip*Transform3D(basis,Vector3(0,-.018,-.018))
static func material(color: Color) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.65;return m
static func mesh_part(parent: Node3D,mesh: Mesh,at: Vector3,mat: Material):
	var node:=MeshInstance3D.new();node.mesh=mesh;node.position=at;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node);return node
static func model(kind: int) -> Node3D:
	var root:=Node3D.new();var body:=CylinderMesh.new();body.top_radius=.035;body.bottom_radius=.035;body.height=.115;body.radial_segments=12
	var shell:=material([Color("4c583c"),Color("606668"),Color("547056")][kind]);var steel:=material(Color("343a3b"));steel.metallic=.65
	mesh_part(root,body,Vector3.ZERO,shell)
	var stripe:=CylinderMesh.new();stripe.top_radius=.036;stripe.bottom_radius=.036;stripe.height=.018;stripe.radial_segments=12
	mesh_part(root,stripe,Vector3(0,.025,0),material([Color("c7a437"),Color("b6c0bc"),Color("aa5939")][kind]))
	var neck:=CylinderMesh.new();neck.top_radius=.018;neck.bottom_radius=.024;neck.height=.019;neck.radial_segments=10;mesh_part(root,neck,Vector3(0,.065,0),steel)
	var lever:=BoxMesh.new();lever.size=Vector3(.014,.09,.009);var handle=mesh_part(root,lever,Vector3(.029,.033,0),steel);handle.rotation.z=.18
	var cap:=BoxMesh.new();cap.size=Vector3(.044,.008,.015);mesh_part(root,cap,Vector3(.01,.075,0),steel)
	var ring:=TorusMesh.new();ring.inner_radius=.009;ring.outer_radius=.013;ring.rings=12;ring.ring_segments=6;var pin=mesh_part(root,ring,Vector3(-.024,.069,0),steel);pin.rotation.x=PI/2
	return root
func cloud() -> Node3D:
	var root:=Node3D.new();var puff:=QuadMesh.new();puff.size=Vector2(2,2)
	var mat:=ShaderMaterial.new();mat.shader=preload("res://deathmatch/counterstrike/smoke.gdshader")
	for i in 13:
		var at:=Vector3.ZERO if i==0 else Vector3(sin(i*2.4)*.48,.3*sin(i*1.7),cos(i*2.4)*.48)
		var part=mesh_part(root,puff,at,mat);part.scale=Vector3.ONE*(.7 if i>0 else 1.0);part.extra_cull_margin=2
	root.set_meta("material",mat);return root
func overlays():
	if not layer:
		layer=CanvasLayer.new();layer.layer=90;add_child(layer);screen=ColorRect.new();screen.mouse_filter=Control.MOUSE_FILTER_IGNORE;screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(screen)
	if game.is_vr() and not is_instance_valid(eye_quad):
		eye_quad=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(2,2);eye_quad.mesh=quad;eye_quad.extra_cull_margin=100
		eye_material=ShaderMaterial.new();eye_material.shader=preload("res://deathmatch/counterstrike/utility_overlay.gdshader");eye_material.render_priority=125
		eye_quad.material_override=eye_material;game.xr_rig.head.add_child(eye_quad);eye_quad.position.z=-.08
func _exit_tree():
	if is_instance_valid(eye_quad):eye_quad.queue_free()
func update():
	var viewpoint: int=game.demos.selected_player if game.demos.playing and game.demos.viewpoint=="first" else game.multiplayer.get_unique_id()
	for id in meshes.keys():
		if not utility.flying.has(id):meshes[id].queue_free();meshes.erase(id)
	for id in utility.flying:
		var p: Dictionary=utility.flying[id]
		if not meshes.has(id):meshes[id]=model(p.kind);add_child(meshes[id])
		meshes[id].position=p.position;meshes[id].rotation=Vector3(p.age*8,p.age*5,.4)
	for id in smoke.keys():
		if not utility.clouds.has(id):smoke[id].queue_free();smoke.erase(id)
	for id in utility.clouds:
		var c: Dictionary=utility.clouds[id]
		if not smoke.has(id):smoke[id]=cloud();add_child(smoke[id])
		smoke[id].position=c.position;smoke[id].scale=Vector3.ONE*maxf(.01,utility.cloud_radius(c.age))
		smoke[id].get_meta("material").set_shader_parameter("density",utility.cloud_density(c.age))
	for id in hands.keys():
		if not utility.rules.alive(id) or utility.selected(id)<0 or hands[id].get_meta("kind")!=utility.selected(id):hands[id].queue_free();hands.erase(id)
	for id in game.players:
		var kind: int=utility.selected(id)
		if kind<0 or not utility.rules.alive(id):continue
		if not hands.has(id):hands[id]=model(kind);hands[id].set_meta("kind",kind);add_child(hands[id])
		hands[id].visible=not (id==game.multiplayer.get_unique_id() and game.is_vr() and game.xr_rig.physical_actions.available)
		if id==viewpoint and not game.is_vr():hands[id].global_transform=game.camera.global_transform*Transform3D(Basis(Vector3.RIGHT,.3),Vector3(.18,-.22,-.42))
		elif not game.players[id].xr.is_empty():
			var pose: Dictionary=game.players[id].xr
			var hand: Transform3D=(pose.right if pose.left_handed else pose.left) if utility.state(id).get("offhand",false) else utility.rules.Interaction.primary(pose)
			var left: bool=not pose.left_handed if utility.state(id).get("offhand",false) else pose.left_handed
			hands[id].global_transform=utility.rules.base_pose(id)*held_pose(hand,left)
		else:hands[id].global_transform=utility.rules.base_pose(id)*Transform3D(Basis.IDENTITY,Vector3(.2,1.05,-.4))
	overlays()
	var at: Vector3=game.xr_rig.head.global_position if game.is_vr() else game.camera.global_position
	var blind: float=utility.flash_amount(viewpoint);var fog: float=utility.smoke_amount(at)
	if game.local_state().get("dead",true) or game.demos.playing and game.demos.viewpoint!="first":blind=0
	if game.menu_open:blind=0;fog=0
	var alpha: float=blind+fog*(1-blind)
	screen.visible=not game.is_vr() and alpha>.001;screen.color=Color(Color(.57,.60,.58).lerp(Color.WHITE,blind),alpha)
	if is_instance_valid(eye_quad):
		eye_quad.visible=game.is_vr() and alpha>.001;eye_material.set_shader_parameter("flash",blind);eye_material.set_shader_parameter("smoke",fog)
