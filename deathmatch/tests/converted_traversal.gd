extends SceneTree
const Maps=preload("res://deathmatch/maps/loader.gd")
const Fighter=preload("res://deathmatch/fighter.gd")
var game
var runtime
var level
var report: Dictionary={}
var failures: Array=[]
var next_id:=10000
func _initialize():call_deferred("run")
func vec(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
func xyz(p: Vector3) -> Array:return [p.x,p.y,p.z]
func actor_at(p: Vector3):
 var a=Fighter.new();next_id+=1;a.setup(next_id,"audit",Color.WHITE);a.collision_mask=1;a.quake_movement=true;game.add_child(a);a.position=p;return a
func probe(p: Vector3,radius: float=.04) -> Array:
 var q:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=radius;q.shape=sphere;q.transform.origin=p;q.collision_mask=1
 return game.get_world_3d().direct_space_state.intersect_shape(q,128)
func capsule_hits(p: Vector3) -> Array:
 var q:=PhysicsShapeQueryParameters3D.new();var shape:=CapsuleShape3D.new();shape.height=1.65;shape.radius=.30;q.shape=shape;q.transform.origin=p+Vector3.UP*.83;q.collision_mask=1;q.margin=.001
 return game.get_world_3d().direct_space_state.intersect_shape(q,128)
func clear_capsule(p: Vector3) -> bool:return capsule_hits(p).is_empty()
func fail(label: String):failures.append(label);print("FAIL ",label)
func run() -> void:
 var args:=OS.get_cmdline_user_args();var input: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 report={"name":input.name,"path":input.path,"sha256":input.sha256,"entity_counts":input.counts,"liquid_leaves":input.liquid_leaves,"unsupported_logic":input.unsupported_logic,"unresolved_targets":input.unresolved_targets,"spawns":[],"water":[],"doors":[],"lifts":[],"teleports":[],"push_triggers":[]}
 var error:=Maps.validate(input.path)
 if not error.is_empty():fail(error);finish(args[1]);return
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false);game.dedicated=true
 for child in game.get_node("Map").get_children():child.free()
 for key in ["gates","lifts","spawn_points","spawn_yaws","pickups"]:game.get(key).clear()
 game.map_objectives.clear();game.ctf_spawns=[[],[]];game.tf_resupply=[[],[]];game.tf_capture.clear()
 level=Maps.read(input.path)
 if not level:fail("Importer returned no map");finish(args[1]);return
 game.get_node("Map").add_child(level)
 report.import_collision_alignment=true;report.legacy_shapes_exercised=0
 for node in level.get_children():
  if not node is PhysicsBody3D or not "attributes" in node:continue
  if not str(node.attributes.get("model","")).begins_with("*"):continue
  var expected:=Transform3D(node.transform.basis.inverse(),Vector3.ZERO)
  for shape in node.get_children():
   if shape is CollisionShape3D and shape.shape is ConcavePolygonShape3D:
    if not shape.transform.is_equal_approx(expected):report.import_collision_alignment=false
    if not node.transform.basis.is_equal_approx(Basis.IDENTITY):report.legacy_shapes_exercised+=1
    shape.transform=Transform3D.IDENTITY
 if not report.import_collision_alignment:fail("Fresh brush import misaligns mesh and collision")
 runtime=preload("res://deathmatch/maps/runtime.gd").new();game.get_node("Map").add_child(runtime);runtime.configure(game,level,input.path);runtime.set_physics_process(false);runtime.set_process(false)
 game.active=true;await physics_frame;await physics_frame
 report.contents_loaded=runtime.has_contents
 if not runtime.has_contents:fail("BSP contents unavailable")
 await check_spawns()
 await check_water(input.water_bounds)
 await check_doors()
 await check_lifts()
 await check_triggers()
 if not input.unsupported_logic.is_empty():report.logic_note="Buttons/trigger target chains are not executed by current runtime; secret doors use one-stage proximity sliding. Lifts run timed cycles, not Quake trigger scheduling."
 finish(args[1])
func check_spawns() -> void:
 var actors: Array=[]
 for p in game.spawn_points:
  var a=actor_at(p);actors.append(a);report.spawns.append({"position":xyz(p),"capsule_clear":clear_capsule(p),"grounded":false,"jump_rise":0.0})
 for frame in 45:
  await physics_frame
  for a in actors:a.simulate(Vector2.ZERO,0,false,1.0/60)
 for i in actors.size():
  var a=actors[i];report.spawns[i].grounded=a.is_on_floor();report.spawns[i].settled=xyz(a.position)
  if not report.spawns[i].capsule_clear:fail("Spawn capsule overlaps solid: "+str(i))
  if not a.is_on_floor() and not runtime.contents.liquid(runtime.contents.at(a.position+Vector3.UP*.75)):fail("Spawn did not find floor or water: "+str(i))
 for frame in 20:
  await physics_frame
  for a in actors:a.simulate(Vector2.ZERO,0,false,1.0/60,true)
 for i in actors.size():
  var a=actors[i];report.spawns[i].jump_rise=a.position.y-float(report.spawns[i].settled[1]);report.spawns[i].finite=a.position.is_finite()
  if not a.position.is_finite():fail("Nonfinite spawn movement")
 for frame in 40:
  await physics_frame
  for a in actors:a.simulate(Vector2(1,0),0,false,1.0/60,false)
 for i in actors.size():
  report.spawns[i].walk_end=xyz(actors[i].position)
  report.spawns[i].movement_finite=actors[i].position.is_finite()
  if not actors[i].position.is_finite():fail("Nonfinite directional movement")
  actors[i].free()
func check_water(boxes: Array) -> void:
 var positions: Array=[]
 for box in boxes:
  var lo:=vec(box.lo);var hi:=vec(box.hi)
  for fraction in [.5,.25,.75]:
   var q:=lo.lerp(hi,fraction);var p:=Vector3(-q.y,q.z,-q.x)/32.0-Vector3.UP*.75
   if runtime.contents.at(p+Vector3.UP*.75)!=-3 or not clear_capsule(p):continue
   if positions.any(func(other):return other.distance_to(p)<3):continue
   positions.append(p);break
  if positions.size()>=12:break
 report.water_sample_count=positions.size()
 if not boxes.is_empty() and positions.is_empty():report.water_note="Water leaves exist but no capsule-clear sampled liquid location; no swimming pass claimed."
 var actors: Array=[]
 for p in positions:
  var a=actor_at(p);actors.append(a);game.players[a.peer_id]=game._new_state("swimmer",a.peer_id);game.players[a.peer_id].hp=10000;game.fighters[a.peer_id]=a
  report.water.append({"position":xyz(p),"sinking":0.0,"rise":0.0,"stroke_down":0.0})
 await physics_frame;await physics_frame
 runtime._physics_process(1.0/60)
 for i in actors.size():
  if not actors[i].in_water:fail("Actual water sample did not enter swimming")
  report.water[i].underwater=actors[i].underwater
 for frame in 20:
  await physics_frame;runtime._physics_process(1.0/60)
  for a in actors:a.simulate(Vector2.ZERO,0,false,1.0/60)
 for i in actors.size():report.water[i].sinking=actors[i].velocity.y;actors[i].position=positions[i];actors[i].velocity=Vector3.ZERO
 for frame in 24:
  await physics_frame;runtime._physics_process(1.0/60)
  for a in actors:a.simulate(Vector2.ZERO,0,false,1.0/60,true)
 for i in actors.size():
  report.water[i].rise=actors[i].position.y-positions[i].y
  # A capsule-clear starting point may still sit immediately below a ceiling.
  # Compare measured rise against actual headroom before blaming swimming.
  var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.height=1.65;capsule.radius=.30
  query.shape=capsule;query.transform.origin=positions[i]+Vector3.UP*.83;query.motion=Vector3.UP;query.collision_mask=1;query.margin=.001
  var sweep_up: PackedFloat32Array=game.get_world_3d().direct_space_state.cast_motion(query)
  report.water[i].upward_headroom=sweep_up[0]
  report.water[i].upward_blocked_by_geometry=sweep_up[0]<.05
  if report.water[i].rise<.05 and sweep_up[0]>=.05:fail("Water sample cannot swim upward: "+str(i))
  actors[i].position=positions[i];actors[i].velocity=Vector3.ZERO
 for frame in 15:
  await physics_frame;runtime._physics_process(1.0/60)
  for a in actors:a.simulate(Vector2.ZERO,0,false,1.0/60,false,Vector3.DOWN)
 for i in actors.size():
  var a=actors[i];report.water[i].stroke_down=a.position.y-positions[i].y
  # Test state transitions against the actual contents tree at a dry spawn.
  var dry=game.spawn_points.filter(func(p):return runtime.contents.at(p+Vector3.UP*1.48)==-1)
  if not dry.is_empty():
   a.position=dry[0];runtime._physics_process(1.0/60);report.water[i].dry_exit=not a.in_water and not a.underwater and a.air_left==12
   if not report.water[i].dry_exit:fail("Dry exit retains water state")
  var surface: Vector3=positions[i]+Vector3.UP*.75;var found:=false
  for step in 100:
   var point:=surface+Vector3.UP*(step*.25)
   if runtime.contents.at(point)==-1 and runtime.contents.at(point+Vector3.UP*.75)==-1 and runtime.contents.at(point+Vector3.UP*1.6)==-1:
    surface=point;found=clear_capsule(point-Vector3.UP*1.6) and clear_capsule(point+Vector3.UP*.25);break
   if runtime.contents.at(point)==-2:break
  if found:
   var q:=PhysicsShapeQueryParameters3D.new();var shape:=CapsuleShape3D.new();shape.height=1.65;shape.radius=.30;q.shape=shape
   q.transform.origin=surface-Vector3.UP*1.6+Vector3.UP*.83;q.motion=Vector3.UP*1.85;q.collision_mask=1;q.margin=.001
   var sweep: PackedFloat32Array=game.get_world_3d().direct_space_state.cast_motion(q)
   report.water[i].surface=xyz(surface);report.water[i].surface_sweep_fraction=sweep[0]
   found=sweep[0]>.999
   report.water[i].surface_blocked_by_geometry=not found
  report.water[i].surface_exit_tested=found
  if found:
   a.position=surface-Vector3.UP*1.6;a.velocity=Vector3.ZERO
   report.water[i].surface=xyz(surface);report.water[i].exit_start=xyz(a.position)
   report.water[i].exit_start_contents=runtime.contents.at(a.position+Vector3.UP*.75)
   var emerged:=false;var peak_y: float=a.position.y;var contacts: Array=[]
   for frame in 40:
    await physics_frame;runtime._physics_process(1.0/60);a.simulate(Vector2.ZERO,0,false,1.0/60,true)
    peak_y=maxf(peak_y,a.position.y)
    for contact_index in a.get_slide_collision_count():
     var collision=a.get_slide_collision(contact_index);var contact={"position":xyz(collision.get_position()),"normal":xyz(collision.get_normal()),"collider":str(collision.get_collider().name)}
     if not contacts.has(contact):contacts.append(contact)
    if not a.in_water and not a.underwater:emerged=true
   report.water[i].physical_surface_exit=emerged
   report.water[i].exit_peak_y=peak_y;report.water[i].exit_contacts=contacts
   if not emerged:fail("Clear water surface cannot be exited: "+str(i))
  game.players.erase(a.peer_id);game.fighters.erase(a.peer_id);a.free()
func check_doors() -> void:
 if game.gates.is_empty():return
 # Earlier swimming probes can legitimately open a nearby door. Establish
 # a closed baseline through the production animation before collision tests.
 for i in game.gates.size():game._gate_state(i,false)
 for frame in 44:await physics_frame
 var markers: Array=[]
 for i in game.gates.size():
  var gate=game.gates[i];var closed: Vector3=gate.node.position;var b: AABB=runtime.node_bounds(gate.node);var marker=b.get_center()
  # A brush can have a hollow center. Probe a real collision triangle near
  # the visual bounds center rather than assuming its AABB center is solid.
  var nearest:=INF;var trailing:=INF;var marker_normal:=Vector3.UP
  var travel_direction: Vector3=gate.travel.normalized()
  for shape in gate.node.get_children():
   if not shape is CollisionShape3D or not shape.shape is ConcavePolygonShape3D:continue
   var faces: PackedVector3Array=shape.shape.get_faces()
   for face in range(0,faces.size(),3):
    var point: Vector3=shape.global_transform*((faces[face]+faces[face+1]+faces[face+2])/3)
    var distance:=point.distance_squared_to(b.get_center())
    var projection:=point.dot(travel_direction)
    if projection<trailing-.001 or absf(projection-trailing)<.001 and distance<nearest:
     trailing=projection;nearest=distance;marker=point
     marker_normal=(shape.global_transform.basis*((faces[face+1]-faces[face]).cross(faces[face+2]-faces[face]))).normalized()
  marker+=marker_normal*.02
  var hit:=probe(marker).any(func(row):return row.collider==gate.node)
  if not hit:
   marker-=marker_normal*.04
   hit=probe(marker).any(func(row):return row.collider==gate.node)
  if not hit:fail("Door has no collision at its triangle probe: "+str(i))
  markers.append(marker);report.doors.append({"entity":gate.node.attributes,"closed":xyz(closed),"travel":xyz(gate.travel),"closed_probe_hits_door":hit})
  var a=actor_at(gate.center);game.players[a.peer_id]=game._new_state("door probe",a.peer_id);game.fighters[a.peer_id]=a
 runtime._physics_process(1.0/60)
 for i in game.gates.size():
  report.doors[i].proximity_opens=game.gates[i].open
  if not game.gates[i].open:fail("Door proximity activation failed: "+str(i))
 for a in game.fighters.values():a.free()
 game.fighters.clear();game.players.clear()
 for frame in 44:await physics_frame
 for i in game.gates.size():
  var gate=game.gates[i];var row=report.doors[i];row.reached_open=gate.node.position.distance_to(gate.base_position+gate.travel)<.02
  row.old_probe_clear_of_door=not probe(markers[i]).any(func(h):return h.collider==gate.node)
  if not row.reached_open:fail("Door did not reach open endpoint: "+str(i))
  if row.closed_probe_hits_door and not row.old_probe_clear_of_door:fail("Open door still blocks its closed-position probe: "+str(i))
  game._gate_state(i,false)
 for frame in 44:await physics_frame
 for i in game.gates.size():
  var gate=game.gates[i];report.doors[i].returned_closed=gate.node.position.distance_to(gate.base_position)<.02
  if not report.doors[i].returned_closed:fail("Door did not close: "+str(i))
  report.doors[i].closed_collision_restored=probe(markers[i]).any(func(h):return h.collider==gate.node)
  if report.doors[i].closed_probe_hits_door and not report.doors[i].closed_collision_restored:fail("Door collision did not return: "+str(i))
func check_lifts() -> void:
 if game.lifts.is_empty():return
 var riders: Array=[]
 for lift in game.lifts:
  var b: AABB=runtime.node_bounds(lift.node);var start:=Vector3(b.get_center().x,b.end.y+.03,b.get_center().z)
  var supported:=false;var supports: Array=[]
  for x in [.5,.2,.8]:
   for z in [.5,.2,.8]:
    var point:=Vector3(b.position.x+b.size.x*x,b.end.y+.05,b.position.z+b.size.z*z)
    var ray: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point,point-Vector3.UP*(b.size.y+1),1))
    if ray.is_empty():continue
    var candidate: Vector3=ray.position+Vector3.UP*.03
    if ray.collider==lift.node and clear_capsule(candidate):start=candidate;supported=true;break
    supports.append(ray.collider.attributes if "attributes" in ray.collider else {"node":str(ray.collider.name)})
   if supported:break
  var a=actor_at(start);riders.append(a)
  report.lifts.append({"entity":lift.node.attributes,"base":lift.base,"travel":lift.travel,"start":xyz(start),"capsule_clear":clear_capsule(start),"sampled_lift_support":supported,"other_supports":supports,"collision_shapes":lift.node.find_children("*","CollisionShape3D",true,false).size()})
  if not supported:fail("No boardable lift surface among nine samples: "+str(report.lifts.size()-1))
 for frame in 20:
  await physics_frame
  for a in riders:a.simulate(Vector2.ZERO,0,false,1.0/60)
 for i in riders.size():
  report.lifts[i].boarded=riders[i].is_on_floor();report.lifts[i].start_y=riders[i].position.y
  var q:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.height=1.65;capsule.radius=.30;q.shape=capsule
  q.transform.origin=riders[i].position+Vector3.UP*.83;q.motion=Vector3.UP*float(game.lifts[i].travel);q.collision_mask=1;q.exclude=[game.lifts[i].node.get_rid()]
  var sweep: PackedFloat32Array=game.get_world_3d().direct_space_state.cast_motion(q)
  report.lifts[i].overhead_clear_fraction=sweep[0]
 # Drive the production arena tick: empty dedicated server skips combat only.
 for frame in 121:
  game.round_left=game.time_limit-(2.0+frame/60.0);game._physics_process(1.0/60)
  await physics_frame
  for a in riders:a.simulate(Vector2.ZERO,0,false,1.0/60)
 for i in riders.size():
  var lift=game.lifts[i];var row=report.lifts[i];row.reached_top=absf(lift.node.position.y-lift.base-lift.travel)<.02;row.rider_rise=riders[i].position.y-row.start_y
  row.carried=absf(row.rider_rise-lift.travel)<.3
  if not row.reached_top:fail("Lift did not reach top: "+str(i))
  if row.boarded and row.capsule_clear and not row.carried:fail(("Lift passenger stopped by overhead map geometry: " if row.overhead_clear_fraction<.99 else "Lift failed to carry rider: ")+str(i))
 for frame in 121:
  game.round_left=game.time_limit-(8.0+frame/60.0);game._physics_process(1.0/60)
  await physics_frame
  for a in riders:a.simulate(Vector2.ZERO,0,false,1.0/60)
 for i in riders.size():
  var lift=game.lifts[i];var row=report.lifts[i]
  row.returned_bottom=absf(lift.node.position.y-lift.base)<.02
  row.rider_returned=absf(riders[i].position.y-row.start_y)<.3
  if not row.returned_bottom:fail("Lift did not return to bottom: "+str(i))
  if row.carried and not row.rider_returned:fail("Lift did not return passenger: "+str(i))
  riders[i].free()
 for lift in game.lifts:lift.node.position.y=lift.base
 await physics_frame
func check_triggers() -> void:
 var a=actor_at(Vector3(10000,10000,10000));game.players[a.peer_id]=game._new_state("trigger probe",a.peer_id);game.players[a.peer_id].hp=10000;game.fighters[a.peer_id]=a
 for region in runtime.regions:
  if not region.kind in ["trigger_teleport","trigger_push"]:continue
  var bounds:=AABB()
  for shape in region.area.get_children():
   if shape is CollisionShape3D and shape.shape is BoxShape3D:
    bounds=shape.global_transform*AABB(-shape.shape.size/2,shape.shape.size);break
  var p:=bounds.get_center()-Vector3.UP*.75;a.position=p;a.velocity=Vector3.ZERO;game.clock+=2;runtime.teleport_until.clear()
  var serial: int=game.players[a.peer_id].serial
  await physics_frame;await physics_frame;await physics_frame
  var overlaps: bool=region.area.overlaps_body(a)
  var overlapping: Array=[]
  for candidate in runtime.regions:
   if candidate.kind=="trigger_teleport" and candidate.area.overlaps_body(a):overlapping.append(candidate.data)
  var ambiguous:=overlapping.size()>1
  if region.kind=="trigger_teleport" and ambiguous:
   # Adjacent narrow portals can both overlap a capsule at a box center.
   # Choose an unambiguous approach point, retaining the ambiguity in the report.
   for x in [.2,.8,.5]:
    for z in [.2,.8,.5]:
     p=Vector3(bounds.position.x+bounds.size.x*x,bounds.get_center().y-.75,bounds.position.z+bounds.size.z*z);a.position=p
     await physics_frame;await physics_frame
     overlapping.clear()
     for candidate in runtime.regions:
      if candidate.kind=="trigger_teleport" and candidate.area.overlaps_body(a):overlapping.append(candidate.data)
     if overlapping.size()==1 and region.area.overlaps_body(a):break
    if overlapping.size()==1 and region.area.overlaps_body(a):break
   overlaps=region.area.overlaps_body(a)
  runtime._physics_process(1.0/60)
  var row: Dictionary={"entity":region.data,"source":xyz(p),"overlap":overlaps,"ambiguous_center":ambiguous,"overlapping_teleports":overlapping,"actual_destination":xyz(a.position)}
  if region.kind=="trigger_teleport":
   var target: String=region.data.get("target","");row.resolved=runtime.destinations.has(target)
   row.fired=game.players[a.peer_id].serial>serial
   if row.resolved:
    var dest: Vector3=runtime.destinations[target].position;row.destination=xyz(dest);row.correct_destination=a.position.distance_to(dest)<.02;row.destination_clear=clear_capsule(dest)
    if not row.correct_destination:fail("Teleporter did not reach target: "+target)
    row.destination_blockers=[]
    for hit in capsule_hits(dest):row.destination_blockers.append(hit.collider.attributes if "attributes" in hit.collider else {"node":str(hit.collider.name)})
    if not row.destination_clear:fail("Teleporter destination overlaps solid: "+target)
   else:fail("Unresolved teleporter target: "+target)
   report.teleports.append(row)
  else:
   row.velocity=xyz(a.velocity);row.fired=a.velocity.length()>.1;report.push_triggers.append(row)
  if not overlaps or not row.fired:fail("Trigger did not activate: "+str(region.data))
 game.players.clear();game.fighters.clear();a.free()
func finish(path: String):
 report.failures=failures;report.engine=Engine.get_version_info().string
 var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 if is_instance_valid(game):game.active=false;game.free()
 print("TRAVERSAL_RESULT ",report.name," ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
