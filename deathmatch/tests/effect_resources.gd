extends SceneTree
## Resource reuse must retain independent effects and the existing visual bounds.
const Visuals=preload("res://deathmatch/experimental/visuals.gd")
const Spatial=preload("res://deathmatch/audio/spatial.gd")
var failures: Array=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	var fx:=Visuals.new();root.add_child(fx);fx.set_process(false)
	var nodes: Array=[];var materials: Array=[];var traces: Array=[]
	for item in fx.free_shapes:
		nodes.append(item.node.get_instance_id());materials.append(item.mat.get_instance_id());traces.append(item.trace.get_instance_id())
	var points:=PackedVector3Array([Vector3.ZERO,Vector3(0,0,-3)])
	fx.streak(points,Color(1,.2,.1,.8),.02,.4)
	var first: Dictionary=fx.shapes[0];var vertices: PackedVector3Array=first.trace.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(vertices.size()==12 and first.trace.get_aabb().is_equal_approx(AABB(Vector3(-.02,-.02,-3),Vector3(.04,.04,3))),"Tracer retains crossed-strip width and endpoints")
	fx.streak(PackedVector3Array([Vector3.ONE,Vector3(1,4,1),Vector3(2,4,1)]),Color(.1,.2,1,.4),.03,.2)
	check(first.trace.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==vertices,"Another tracer does not overwrite live geometry")
	check(fx.shapes[0].mat!=fx.shapes[1].mat,"Overlapping effects have independent color and fade")
	fx._process(.1)
	check(is_equal_approx(first.mat.albedo_color.a,.6) and is_equal_approx(fx.shapes[1].mat.albedo_color.a,.2),"Opacity follows each effect's own lifetime")
	fx._process(.11)
	check(fx.shapes.size()==1 and fx.free_shapes.size()==Visuals.MAX_SHAPES-1,"Expiry retires only the finished effect")
	fx.clear()
	fx.ring(Vector3.ONE,Color.GREEN,3,.5);fx.globe(Vector3.ZERO,Color.BLUE,2,.5)
	check(is_equal_approx(fx.shapes[0].node.scale.x,.2) and is_equal_approx(fx.shapes[1].node.scale.x,.12),"Ring and globe retain initial scale")
	fx._process(.25)
	check(is_equal_approx(fx.shapes[0].node.scale.x,3.1) and is_equal_approx(fx.shapes[1].node.scale.x,2.06),"Ring and globe retain expansion curves")
	fx.clear()
	for i in Visuals.MAX_SHAPES*3:
		fx.streak(points,Color.WHITE,.01,.1)
		check(nodes.has(fx.shapes.back().node.get_instance_id()) and materials.has(fx.shapes.back().mat.get_instance_id()) and traces.has(fx.shapes.back().trace.get_instance_id()),"Sustained fire reuses startup resources")
	check(fx.shapes.size()==Visuals.MAX_SHAPES and fx.free_shapes.is_empty(),"Sustained fire respects the total shape budget")
	fx.clear();fx.clear()
	check(fx.free_shapes.size()==Visuals.MAX_SHAPES and fx.get_child_count()==Visuals.MAX_SHAPES+2,"Repeated map clear retains a bounded reusable pool")
	check(fx.free_shapes.all(func(item):return not item.node.visible),"Cleared shapes are hidden")
	fx.free()
	var audio:=Spatial.new()
	seed(1729);var expected:=randi();seed(1729);audio.prewarm()
	check(randi()==expected,"Sound preparation does not consume gameplay random values")
	var cached: Dictionary=audio.cache.duplicate()
	for kind in ["hit_confirm","impact_energy","impact_heavy","impact_dust","pain","flesh","step","impact","jump","land","death","gib"]:
		for i in 40:check(audio.choose(kind)!=null,"Prepared sound remains available: "+kind)
	for rules in ["cs16","quake","ut99","tribes"]:
		for slot in (10 if rules=="quake" else 12):
			check(audio.choose("%s_weapon_%d"%[rules,slot])!=null,"Prepared weapon sound remains available")
	check(audio.cache==cached,"Common and randomized combat sound queries need no cold loads")
	audio.prewarm();check(audio.cache==cached,"Sound preparation is idempotent")
	audio.free()
	print("EFFECT_RESOURCES_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
