extends "res://deathmatch/experimental/visuals.gd"
signal nvg_flash(position:Vector3,radius:float,duration:float,size:float,energy:float)
func beam(color:Color,start:Vector3,end:Vector3) -> void:
	var ray:=Node3D.new();add_child(ray);ray.position=(start+end)*.5
	if start.distance_to(end)>.001:ray.look_at(end)
	Art.barrel(ray,Vector3.ZERO,.012,start.distance_to(end),energy_material(color))
	get_tree().create_timer(.12).timeout.connect(ray.queue_free)
func impacts(_rules:String,start:Vector3,ends:PackedVector3Array,weapon:int,definition:Dictionary={}) -> void:
	if definition.get("cq_beam",false):
		for end in ends:beam(definition.color,start,end);burst("ut99",end,weapon,"energy",{"cq_effect":"energy","color":definition.color})
		return
	var bullet:=definition.duplicate();bullet.kind="hitscan"
	super.impacts("cs16",start,ends,weapon,bullet)
func energy_material(color:Color) -> StandardMaterial3D:
	var result:=material(color);result.emission_enabled=true;result.emission=color;result.emission_energy_multiplier=2.0;return result
func projectile(rules:String,definition:Dictionary) -> Node3D:
	if definition.get("cq_bullet",false):
		var bullet:=Node3D.new();Art.barrel(bullet,Vector3.ZERO,.009,.25,energy_material(Color("ffe5a5")));return bullet
	if not definition.has("cq_effect"):return super.projectile(rules,definition)
	var root:=Node3D.new();var color:Color=definition.color
	root.set_meta("cq_effect",definition.cq_effect);root.set_meta("color",color);root.set_meta("trail_time",0.0)
	root.set_meta("emission",{"color":color,"radius":1.5,"energy":.6,"life":.1})
	if definition.cq_effect=="energy":
		Art.barrel(root,Vector3.ZERO,.025,.55,energy_material(color));Art.barrel(root,Vector3.ZERO,.009,.56,energy_material(color.lightened(.8)))
	else:
		var globe:=SphereMesh.new();globe.radius=.18;globe.height=.36;globe.radial_segments=12;globe.rings=6
		var node:=MeshInstance3D.new();node.mesh=globe;node.material_override=energy_material(color);root.add_child(node)
		Art.barrel(root,Vector3.ZERO,.07,.65,energy_material(color.lightened(.75)))
	return root
func travel(node:Node3D,velocity:Vector3,delta:float,stuck:bool) -> void:
	if not node.has_meta("cq_effect"):super.travel(node,velocity,delta,stuck);return
	var time:float=node.get_meta("trail_time",0.0)+delta
	if time>.05:
		node.set_meta("trail_time",0.0);particle(node.global_position,-velocity.normalized()*.5,node.get_meta("color"),.04,.15)
	else:node.set_meta("trail_time",time)
func burst(rules:String,pos:Vector3,weapon:int,kind:String="",definition:Dictionary={}) -> void:
	if definition.get("cq_bullet",false):super.burst("cs16",pos,2,"hitscan",definition);return
	if not definition.has("cq_effect"):super.burst(rules,pos,weapon,kind,definition);return
	var color:Color=definition.color;var ordnance:bool=definition.cq_effect=="ordnance"
	nvg_flash.emit(pos,72. if ordnance else 24.,.5 if ordnance else .16,2.5 if ordnance else .3,1.2 if ordnance else .8)
	globe(pos,color,2.5 if ordnance else .3,.32 if ordnance else .15)
	if ordnance:ring(pos,color.lightened(.2),2.7,.35)
	for i in (20 if ordnance else 7):particle(pos,Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1)).normalized()*(6 if ordnance else 2),color,.06,.35)
	illumination.emit(pos,pos,{"color":color,"radius":4.5 if ordnance else 1.5,"energy":1.0,"life":.3},0)
