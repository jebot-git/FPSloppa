extends Node3D
## Bounded cosmetic effects shared by live network play and demo playback.
const KINDS=["sentry_fire","explosion","napalm","heal","repair","build","scout","sniper","heavy","spy","flame","bounce"]
var game
var bursts: Array[Node3D]=[]
func material(color: Color) -> StandardMaterial3D:
	var result:=StandardMaterial3D.new();result.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;result.albedo_color=color;result.emission_enabled=true;result.emission=color;result.emission_energy_multiplier=1.0;return result
func ball(parent: Node3D,pos: Vector3,size: float,color: Color) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=size*.5;sphere.height=size;sphere.radial_segments=8;sphere.rings=4;mesh.mesh=sphere;mesh.material_override=material(color);mesh.position=pos;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh);return mesh
func line(parent: Node3D,start: Vector3,end: Vector3,width: float,color: Color) -> Node3D:
	var length:=start.distance_to(end)
	if length<.001:return null
	var node=game.Art.box(parent,(start+end)*.5,Vector3(width,width,length),material(color));node.look_at_from_position(node.position,end);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;return node
func emit(kind: String,start: Vector3,end: Vector3,team: int) -> void:
	if game.headless or not kind in KINDS:return
	while bursts.size()>=64:
		var oldest=bursts.pop_front();if is_instance_valid(oldest):oldest.queue_free()
	var root:=Node3D.new();add_child(root);bursts.append(root)
	var color: Color=game.match_mode.COLORS[clampi(team,0,1)]
	var life:=.5
	match kind:
		"sentry_fire":
			line(root,start,end,.018,Color("ffe590"));ball(root,start,.22,Color("fff2bc"));life=.075
			game.spatial.play("weapon_5",start,-12)
		"flame":
			for i in 7:
				var t:=float(i)/7;var puff=ball(root,start.lerp(end,t),.12+t*.42,Color("ff6418").lerp(Color("ffd978"),1-t))
				var tween:=root.create_tween();tween.tween_property(puff,"position",puff.position+(end-start).normalized()*.6,.16)
			life=.18
		"explosion","napalm":
			var burst=ball(root,start,.25,Color("ff7025"));var tween:=root.create_tween();tween.tween_property(burst,"scale",Vector3.ONE*12,.18);tween.tween_property(burst,"scale",Vector3.ONE*.1,.32)
			for i in 8:
				var direction:=Vector3(cos(i*TAU/8),.35+float(i%3)*.25,sin(i*TAU/8)).normalized()
				line(root,start+direction*.25,start+direction*1.4,.06,Color("ffbf56"))
			game.spatial.play("explosion",start,-5)
			life=.55
		"heal","repair":
			color=Color("6af5a6") if kind=="heal" else Color("7ae7ff")
			line(root,start,end,.035,color)
			for i in 4:
				var pos:=end+Vector3(cos(i*TAU/4)*.35,float(i%2)*.25,sin(i*TAU/4)*.35)
				game.Art.box(root,pos,Vector3(.08,.32,.08),material(color));game.Art.box(root,pos,Vector3(.25,.08,.08),material(color))
			var tween:=root.create_tween();tween.tween_property(root,"position",Vector3.UP*.45,.6);life=.6
		"bounce":ball(root,start,.12,Color("ffd488"));life=.12
		_:
			color={"scout":Color("ffe470"),"sniper":Color("a9ef78"),"heavy":Color("afc6ec"),"spy":Color("b6a7f4")}.get(kind,color)
			for i in 10:
				var angle:=TAU*i/10;ball(root,start+Vector3(cos(angle)*.55,.15,sin(angle)*.55),.12,color)
			var tween:=root.create_tween();tween.tween_property(root,"position",Vector3.UP*.5,.55)
	var reference: WeakRef=weakref(root)
	get_tree().create_timer(life).timeout.connect(func():
		var node=reference.get_ref()
		if is_instance_valid(node):bursts.erase(node);node.queue_free()
	)
