extends "res://tools/vrm_to_mdl/profile/impact_visuals.gd"
## Experimental straight-tracer pool; production visual code remains unchanged.
var tracer_nodes: Array=[]
var tracer_materials: Array=[]
var tracer_free: Array=[]
var tracer_active: Array=[]
var tracer_serial:=0
var tracer_emissions:=0
var tracer_fallbacks:=0
var tracer_evictions:=0
var tracer_peak:=0
var tracer_preparation_ms:=0.0
func _ready() -> void:
	super._ready()
	var before:=Time.get_ticks_usec()
	# Same crossed ribbon as the original two-point streak, in unit coordinates.
	var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in [Vector3.RIGHT,Vector3.UP]:
		for v in [-axis,Vector3(0,0,1)-axis,Vector3(0,0,1)+axis,-axis,Vector3(0,0,1)+axis,axis]:mesh.surface_add_vertex(v)
	mesh.surface_end()
	for i in MAX_SHAPES:
		var node:=MeshInstance3D.new();node.mesh=mesh
		var mat:=material(Color.WHITE)
		node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.visible=false
		add_child(node);tracer_nodes.append(node);tracer_materials.append(mat);tracer_free.append(i)
	tracer_preparation_ms=(Time.get_ticks_usec()-before)/1000.0
func reset_measurement() -> void:
	tracer_emissions=0;tracer_fallbacks=0;tracer_evictions=0;tracer_peak=tracer_active.size()
func streak(points: PackedVector3Array,color: Color,width: float,life: float) -> void:
	if points.size()!=2:
		tracer_fallbacks+=1;super.streak(points,color,width,life);return
	var before:=Trace.begin()
	var a:=points[0];var b:=points[1];var forward:=(b-a).normalized()
	var side:=forward.cross(Vector3.UP if absf(forward.y)<.9 else Vector3.RIGHT).normalized()
	var index: int
	if tracer_free.is_empty():
		var oldest: int=0
		for i in tracer_active.size():
			if tracer_active[i].serial<tracer_active[oldest].serial:oldest=i
		index=tracer_active[oldest].slot;tracer_active.remove_at(oldest);tracer_evictions+=1
	else:index=tracer_free.pop_back()
	var node: MeshInstance3D=tracer_nodes[index]
	node.transform=Transform3D(Basis(side*width,forward.cross(side)*width,forward*a.distance_to(b)),a)
	tracer_materials[index].albedo_color=color;node.visible=true
	tracer_serial+=1;tracer_emissions+=1
	tracer_active.append({"slot":index,"life":life,"total":life,"color":color,"serial":tracer_serial})
	tracer_peak=maxi(tracer_peak,tracer_active.size())
	Trace.end("pooled_tracer_emit",before)
func _process(delta: float) -> void:
	var total:=Trace.begin()
	super._process(delta)
	var before:=Trace.begin()
	for i in range(tracer_active.size()-1,-1,-1):
		var item: Dictionary=tracer_active[i];item.life-=delta
		if item.life<=0:
			tracer_nodes[item.slot].visible=false;tracer_free.append(item.slot);tracer_active.remove_at(i);continue
		var color: Color=item.color;color.a*=item.life/item.total
		tracer_materials[item.slot].albedo_color=color
	Trace.end("pooled_tracer_update",before)
	Trace.end("fx_render_update_total",total)
func pool_report() -> Dictionary:
	return {"capacity":MAX_SHAPES,"nodes_created_before_measurement":tracer_nodes.size(),"materials_created_before_measurement":tracer_materials.size(),"preparation_ms":tracer_preparation_ms,"emissions":tracer_emissions,"fallbacks":tracer_fallbacks,"evictions":tracer_evictions,"peak_active":tracer_peak,"active_at_end":tracer_active.size(),"free_at_end":tracer_free.size(),"invariants_ok":tracer_active.size()+tracer_free.size()==MAX_SHAPES,"method":"Shared immutable unit crossed-ribbon mesh, 64 persistent nodes with individual materials configured once; per-shot transform/color/visibility and original linear fade. Multi-point streaks use original path."}
