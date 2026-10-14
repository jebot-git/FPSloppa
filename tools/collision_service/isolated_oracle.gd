extends SceneTree
## Reproduce disputed casts with one target, near origin and at world position.
func _initialize():run.call_deferred()
func v(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func shape(row:Dictionary)->Shape3D:
	var out:Shape3D
	match int(row.kind):
		0:out=BoxShape3D.new();out.size=v(row.half)*2
		1:out=CylinderShape3D.new();out.radius=row.radius;out.height=row.height
		2:out=SphereShape3D.new();out.radius=row.radius
		3:out=CapsuleShape3D.new();out.radius=row.radius;out.height=row.height
	return out
func ray(space,start:Vector3,delta:Vector3)->Dictionary:
	var q=PhysicsRayQueryParameters3D.create(start,start+delta,1);q.hit_from_inside=true;q.hit_back_faces=true
	var h=space.intersect_ray(q)
	return {"hit":not h.is_empty(),"fraction":(h.position-start).dot(delta)/delta.length_squared() if not h.is_empty() else 1.}
func run()->void:
	var args=OS.get_cmdline_user_args();var inputs=JSON.parse_string(FileAccess.get_file_as_string(args[0]));var output:Array=[]
	var world=Node3D.new();root.add_child(world)
	for row in inputs:
		for local in [false,true]:
			var target=StaticBody3D.new();target.collision_layer=1;target.collision_mask=0;world.add_child(target)
			var target_shape=CollisionShape3D.new();target_shape.shape=shape(row.target)
			var axes=row.target.basis;target_shape.transform=Transform3D(Basis(v(axes[0]),v(axes[1]),v(axes[2])),Vector3.ZERO)
			target.add_child(target_shape);target.position=Vector3.ZERO if local else v(row.target.center)
			await physics_frame;await physics_frame
			var space=world.get_world_3d().direct_space_state;var start=v(row.start)-(v(row.target.center) if local else Vector3.ZERO);var delta=v(row.delta)
			if int(row.kind)==0:output.append({"index":row.index,"local":local,"ray":ray(space,start,delta)})
			else:
				for margin in [0.,.001,.01]:
					var q=PhysicsShapeQueryParameters3D.new();q.shape=shape(row.query);q.collision_mask=1;q.margin=margin
					for segments in [1,16,256]:
						var first:=1.;var unsafe:=1.;var hit:=false
						for i in segments:
							q.transform.origin=start+delta*(float(i)/segments);q.motion=delta/segments
							if not space.intersect_shape(q,1).is_empty():first=float(i)/segments;unsafe=first;hit=true;break
							var f=space.cast_motion(q)
							if f[0]<.999999:first=(i+f[0])/segments;unsafe=(i+f[1])/segments;hit=true;break
						output.append({"index":row.index,"local":local,"margin":margin,"segments":segments,"hit":hit,"safe":first,"unsafe":unsafe})
					for offset in [-.0001,0.,.0001,.001]:
						q.transform.origin=start+delta*float(row.native_fraction)+delta.normalized()*offset;q.motion=Vector3.ZERO
						output.append({"index":row.index,"local":local,"margin":margin,"sample_offset_m":offset,"overlap_at_native_hit":not space.intersect_shape(q,1).is_empty()})
			target.queue_free();await physics_frame
	var f=FileAccess.open(args[1],FileAccess.WRITE);f.store_string(JSON.stringify(output,"\t"));f.close();print("ISOLATED_ORACLE ",output.size());quit()
