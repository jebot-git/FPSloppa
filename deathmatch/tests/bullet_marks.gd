extends SceneTree
const Marks=preload("res://deathmatch/effects/bullet_marks.gd")
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func wall(parent: Node,at: Vector3,size: Vector3,moving:=false):
	var body: PhysicsBody3D=AnimatableBody3D.new() if moving else StaticBody3D.new()
	body.position=at;body.collision_layer=1;parent.add_child(body)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape)
	var mesh:=MeshInstance3D.new();var model:=BoxMesh.new();model.size=size;mesh.mesh=model
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.63,.55,.43);mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mesh.material_override=mat;body.add_child(mesh)
	return body
func run():
	var scene:=Node3D.new();root.add_child(scene)
	wall(scene,Vector3(1000,1,-2.1),Vector3(3,2,.2))
	wall(scene,Vector3(1004,1,-2.1),Vector3(2,2,.2),true)
	var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(1000,1,.8);camera.make_current()
	var marks:=Marks.new();scene.add_child(marks);marks.set_process(false)
	await physics_frame;await physics_frame
	check(marks.place(Vector3(1000,1,-2),Vector3.BACK),"Static wall accepts surface-aligned mark")
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var pose: Transform3D=marks.batch.get_instance_transform(0)
	check(pose.basis.z.normalized().is_equal_approx(Vector3.BACK) and is_equal_approx(pose.origin.z,-1.9985),"Mark follows normal with small depth offset")
	check(not marks.place(Vector3(1000,1,-2),Vector3.BACK) and marks.cursor==1,"Repeated coincident shots do not stack coplanar geometry")
	check(not marks.place(Vector3(1001.495,1,-2),Vector3.BACK),"Corner probes reject a mark extending past wall edge")
	check(not marks.place(Vector3(1004,1,-2),Vector3.BACK),"Moving door cannot retain a floating mark")
	marks.enqueue(Vector3(1000,1,-2),Vector3.ZERO);marks.enqueue(Vector3.INF,Vector3.BACK);marks.enqueue(Vector3(2000,1,-2),Vector3.BACK)
	check(marks.pending.is_empty(),"Invalid normals, invalid positions and distant marks are rejected")
	for i in 100:marks.enqueue(Vector3(999.2+float(i%10)*.16,.3+float(i/10)*.14,-2),Vector3.BACK)
	check(marks.pending.size()==Marks.QUEUE_LIMIT,"Shot bursts have a fixed pending budget")
	marks._process(.016)
	check(marks.processed_last_frame==Marks.PER_FRAME and marks.pending.size()==Marks.QUEUE_LIMIT-Marks.PER_FRAME,"Frame work is limited to four marks / sixteen short corner rays")
	marks.pending.clear()
	for i in 150:
		marks.elapsed+=Marks.LIFETIME
		marks.place(Vector3(1000,1,-2),Vector3.BACK)
	check(marks.batch.instance_count==Marks.LIMIT and marks.batch.visible_instance_count==Marks.LIMIT and marks.get_child_count()==1,"Sustained fire reuses 128 instances in one render node")
	marks._process(Marks.LIFETIME+1)
	check(marks.material.get_shader_parameter("clock_time")>marks.born[0]+Marks.LIFETIME,"Shader receives expiry time without per-mark nodes or timers")
	for y in 4:
		for x in 7:marks.place(Vector3(999.15+x*.28,.5+y*.32,-2),Vector3.BACK)
	marks._process(0)
	await process_frame;await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/cs16/rec-feedback/bullet-marks.png")
	marks.draw.hide()
	for i in 8:await process_frame
	var without:=int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	marks.draw.show()
	for i in 8:await process_frame
	var with_marks:=int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("BULLET_MARKS_DRAW_CALLS ",JSON.stringify({"without":without,"with_128_instances":with_marks,"extra":with_marks-without}))
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
	var hit: Dictionary=g._trace(Vector3(1000,1,0),Vector3(1000,1,-5),0)
	check(hit.get("surface_normal",Vector3.ZERO)==Vector3.BACK,"Authoritative trace supplies static wall normal")
	hit=g._trace(Vector3(1004,1,0),Vector3(1004,1,-5),0)
	check(not hit.has("surface_normal"),"Authoritative trace excludes movers")
	hit=g._trace(Vector3(1010,1,0),Vector3(1010,1,-5),0)
	check(not hit.has("surface_normal"),"Misses cannot produce bullet marks")
	g.active=true
	var path:="res://test-results/cs16/rec-feedback/impact-%d.fpsdemo"%Time.get_ticks_usec()
	g.demos.start_record(path)
	g._impacts(Vector3(1000,1,0),PackedVector3Array([Vector3(1000,1,-2)]),3,PackedVector3Array([Vector3.BACK]))
	g._send_snapshot();g.demos.stop_record()
	g.demos.input=FileAccess.open(path,FileAccess.READ);g.demos.input.seek(g.demos.MAGIC.length())
	var frame: Dictionary=g.demos.read_frame()
	check(not frame.is_empty() and frame.events[0][1][3]==PackedVector3Array([Vector3.BACK]),"Impact recording round-trips authoritative surface normals")
	if not frame.is_empty():
		var old:=frame.duplicate(true);old.events[0][1].resize(3)
		check(g.demos.valid_frame(old),"Older three-argument impact recordings remain readable")
		frame.events[0][1][3]=PackedVector3Array([Vector3.INF])
		check(not g.demos.valid_frame(frame),"Recording parser rejects invalid decal normals")
		frame.events[0][1][3]=PackedVector3Array([Vector3.BACK,Vector3.BACK])
		check(not g.demos.valid_frame(frame),"Recording parser rejects mismatched impact arrays")
	g.demos.input.close();g.demos.input=null;DirAccess.remove_absolute(path)
	g.free();scene.free()
	print("BULLET_MARKS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
