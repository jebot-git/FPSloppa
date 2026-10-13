extends SceneTree
const FX=preload("res://deathmatch/experimental/visuals.gd")
const Rules=preload("res://deathmatch/experimental/weapon_rules.gd")
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	assert(ok,message);checks+=1
func expected_vertices(points: PackedVector3Array,width: float) -> Array:
	var result: Array=[]
	for i in range(1,points.size()):
		var a:=points[i-1];var b:=points[i];var forward:=(b-a).normalized()
		var side:=forward.cross(Vector3.UP if absf(forward.y)<.9 else Vector3.RIGHT).normalized()*width
		for axis in [side,forward.cross(side)]:result.append_array([a-axis,b-axis,b+axis,a-axis,b+axis,a+axis])
	return result
func geometry(item: Dictionary,points: PackedVector3Array,width: float) -> void:
	var vertices: PackedVector3Array=item.node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var expected:=expected_vertices(points,width)
	check(vertices.size()==expected.size(),"Ribbon vertex count")
	for i in vertices.size():check((item.node.transform*vertices[i]).distance_to(expected[i])<.00001,"Ribbon preserves world geometry")
func run() -> void:
	var fx:=FX.new();root.add_child(fx);fx.set_process(false)
	var resources: Dictionary={}
	for item in fx.free_shapes:resources[item.slot]=[item.node.get_instance_id(),item.mat.get_instance_id(),item.trace.get_instance_id()]
	check(fx.free_shapes.size()==64,"Pool initialized once")
	var color:=Color(.7,.4,.2,.8)
	for endpoint in [Vector3(4,2,-6),Vector3(3,9,-2),Vector3(3,-9,-2),Vector3(9,1,-2),Vector3(3.01,9,-2.01)]:
		var points:=PackedVector3Array([Vector3(3,1,-2),endpoint]);fx.streak(points,color,.007,1)
		geometry(fx.shapes[-1],points,.007)
		check(fx.shapes[-1].node.mesh==fx.straight_mesh,"Straight tracers share immutable mesh")
	var node: MeshInstance3D=fx.shapes[0].node;var basis: Basis=node.basis
	fx._process(.5)
	check(node.basis.is_equal_approx(basis),"Fading preserves tracer basis/width/length")
	check(is_equal_approx(fx.shapes[0].mat.albedo_color.a,.4),"Independent linear alpha fade")
	fx._process(.6);check(fx.shapes.is_empty() and fx.free_shapes.size()==64,"Expired slots become hidden and reusable")
	var curve:=PackedVector3Array([Vector3.ZERO,Vector3(0,1,-2),Vector3(2,1,-3)])
	fx.streak(curve,color,.006,1);geometry(fx.shapes[-1],curve,.006)
	var reused: Dictionary=fx.shapes[-1];var mesh_id: int=reused.trace.get_instance_id()
	fx.clear();fx.streak(curve,color,.004,1)
	check(fx.shapes[-1].trace.get_instance_id()==mesh_id,"Curved mesh resource reused after clear")
	geometry(fx.shapes[-1],curve,.004)
	fx.clear();fx.ring(Vector3(1,2,3),color,2,1)
	check(fx.shapes[-1].node.mesh==fx.ring_mesh,"Cached torus mesh")
	fx._process(.5);check(fx.shapes[-1].node.scale.is_equal_approx(Vector3.ONE*2.1),"Ring scale expands while fading")
	fx.globe(Vector3(3,2,1),color,3,1)
	check(fx.shapes[-1].node.mesh==fx.globe_mesh,"Cached sphere mesh")
	fx.clear();fx.reset_pool_stats()
	for i in 70:
		match i%4:
			0:fx.streak(PackedVector3Array([Vector3.ZERO,Vector3(0,0,1)]),color,.006,1)
			1:fx.streak(curve,color,.006,1)
			2:fx.ring(Vector3.ZERO,color,1,1)
			3:fx.globe(Vector3.ZERO,color,1,1)
	check(fx.shapes.size()==64 and fx.free_shapes.is_empty(),"All effect types share one capacity")
	check(fx.pool_stats.evictions==6,"Oldest-first overflow eviction")
	check(fx.shape_pool_report().invariants_ok,"No duplicate or lost active/free slots")
	for item in fx.shapes:
		check([item.node.get_instance_id(),item.mat.get_instance_id(),item.trace.get_instance_id()]==resources[item.slot],"Node/material/curved-mesh identity retained across reuse")
		check(item.node.visible,"Reused nodes visible")
	fx.clear();fx.clear();check(fx.free_shapes.size()==64 and fx.shape_pool_report().invariants_ok,"Clear is idempotent")
	for item in fx.free_shapes:check(not item.node.visible,"Inactive nodes hidden")
	fx.streak(PackedVector3Array(),color,.01,1);fx.streak(PackedVector3Array([Vector3.ZERO,Vector3.ZERO]),color,.01,1)
	check(fx.shapes.is_empty(),"Invalid/degenerate straight tracers ignored")
	var rules:=Rules.new();var illumination_count: Array=[0]
	fx.illumination.connect(func(_a,_b,_recipe,_key):illumination_count[0]+=1)
	for profile in Rules.IDS:
		rules.select(profile)
		for slot in rules.table.size():
			fx.clear();fx.impacts(profile,Vector3.ZERO,PackedVector3Array([Vector3(0,0,-4)]),slot,rules.data(slot))
			fx.burst(profile,Vector3.ZERO,slot,str(rules.data(slot).get("kind","")),rules.data(slot))
			fx._process(.01)
			check(fx.shape_pool_report().invariants_ok and fx.shapes.size()<=64 and fx.particles.size()<=512,"Profile effects preserve pool bounds")
			fx._process(2);check(fx.shapes.is_empty(),"Profile shapes expire")
	check(illumination_count[0]>0,"Weapon lighting signals remain active")
	fx.combo(Vector3.ZERO);fx._process(.02);check(fx.shape_pool_report().invariants_ok,"Combo shares pool")
	fx.free()
	print("POOLED_WEAPON_FX_RESULT ",JSON.stringify({"passed":true,"checks":checks,"geometry":true,"mixed_capacity":64,"resource_reuse":true,"profiles":Rules.IDS}))
	quit()
