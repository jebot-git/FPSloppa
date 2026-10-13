extends SceneTree
const Visuals=preload("res://tools/vrm_to_mdl/profile/pooled_visuals.gd")
func _initialize() -> void:check.call_deferred()
func check() -> void:
	var fx:=Visuals.new();root.add_child(fx)
	var color:=Color(.7,.4,.2,.8)
	for b in [Vector3(4,2,-6),Vector3(0,8,0),Vector3(0,-8,0),Vector3(5,0,0),Vector3(.01,7,.01)]:
		var a:=Vector3(3,1,-2);var width:=.007
		fx.streak(PackedVector3Array([a,b]),color,width,1.0)
		var item: Dictionary=fx.tracer_active[-1];var node: MeshInstance3D=fx.tracer_nodes[item.slot]
		var vertices: PackedVector3Array=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var forward: Vector3=(b-a).normalized();var side: Vector3=forward.cross(Vector3.UP if absf(forward.y)<.9 else Vector3.RIGHT).normalized()*width
		var expected: Array=[]
		for axis in [side,forward.cross(side)]:
			expected.append_array([a-axis,b-axis,b+axis,a-axis,b+axis,a+axis])
		assert(vertices.size()==expected.size())
		for i in vertices.size():assert((node.transform*vertices[i]).distance_to(expected[i])<.00001)
	fx._process(.5)
	for item in fx.tracer_active:assert(is_equal_approx(fx.tracer_materials[item.slot].albedo_color.a,.4))
	fx._process(.6)
	assert(fx.tracer_active.is_empty() and fx.tracer_free.size()==64)
	for i in 70:fx.streak(PackedVector3Array([Vector3.ZERO,Vector3(0,0,1)]),color,.006,1)
	assert(fx.tracer_active.size()==64 and fx.tracer_free.is_empty() and fx.tracer_evictions==6)
	var slots: Dictionary={}
	for item in fx.tracer_active:slots[item.slot]=true
	assert(slots.size()==64)
	fx._process(1.1)
	assert(fx.tracer_active.is_empty() and fx.tracer_free.size()==64)
	fx.streak(PackedVector3Array([Vector3.ZERO,Vector3.UP,Vector3(1,1,0)]),color,.006,1)
	assert(fx.tracer_fallbacks==1 and fx.shapes.size()==1)
	fx._process(1.1)
	assert(fx.shapes.is_empty())
	print("TRACER_POOL_CHECK geometry/fade/expiry/capacity/reuse/multipoint-fallback PASS")
	fx.free();quit()
