extends SceneTree
## Real capsule sweeps against box and BSP-like triangle stairs.
const Fighter=preload("res://deathmatch/fighter.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures: Array=[]
var metrics: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func box(parent: Node,pos: Vector3,size: Vector3,triangles: bool=false):
 var body=Fixture.box(parent,pos,size)
 if triangles:
  var mesh:=BoxMesh.new();mesh.size=size
  var shape:=ConcavePolygonShape3D.new();shape.set_faces(mesh.get_faces());body.get_child(0).shape=shape
 return body
func actor(world: Node,p: Vector3):
 var a=Fighter.new();a.setup(1,"Stair contact",Color.WHITE);a.quake_movement=true;world.add_child(a);a.position=p;return a
func run():
 var original_hz:=Engine.physics_ticks_per_second
 for hz in [60,90,144]:
  Engine.physics_ticks_per_second=hz
  var world:=Node3D.new();root.add_child(world)
  var actors: Array=[];var specs: Array=[]
  for triangles in [false,true]:
   for angled in [false,true]:
    var base:=Vector3(specs.size()*20,0,0);var rise:=.375 if angled else .25;var tread:=.5 if angled else .25
    box(world,base+Vector3(0,-.5,0),Vector3(16,1,20),triangles)
    for i in 8:box(world,base+Vector3(0,(i+1)*rise*.5,-1-i*tread),Vector3(14,(i+1)*rise,tread),triangles)
    box(world,base+Vector3(0,4*rise,-6-7*tread-tread*.5),Vector3(14,8*rise,10),triangles)
    var a=actor(world,base+Vector3(-2,.025,.5));actors.append(a)
    specs.append({"base":base,"angle":55.0 if angled else 0.0,"triangles":triangles,"max_travel":0.0})
  for frame in 15:
   await physics_frame
   for a in actors:a.simulate(Vector2.ZERO,0,false,1.0/hz)
  for frame in 5*hz:
   await physics_frame
   for i in actors.size():
    var a=actors[i];var spec=specs[i];var old: Vector3=a.position
    a.simulate(Vector2(sin(deg_to_rad(spec.angle)),-cos(deg_to_rad(spec.angle)))*.1,0,false,1.0/hz)
    var horizontal: float=Vector2(a.position.x-old.x,a.position.z-old.z).length()
    spec.max_travel=maxf(spec.max_travel,horizontal)
  for i in actors.size():
   var a=actors[i];var spec=specs[i];var end: Vector3=a.position-spec.base
   var label:="%d Hz, %s, %.0f degree approach"%[hz,"triangles" if spec.triangles else "boxes",spec.angle]
   check(end.z<-1.7 and end.y>.7,"Low analog input keeps climbing: "+label)
   check(spec.max_travel<1.1/hz+.001,"Step consumes at most one frame of horizontal movement: "+label)
   metrics.append({"hz":hz,"triangles":spec.triangles,"angle":spec.angle,"end":str(end),"max_travel":spec.max_travel})
  world.free();await physics_frame
 Engine.physics_ticks_per_second=original_hz
 var world:=Node3D.new();root.add_child(world)
 var actors: Array=[]
 for i in 3:
  var base:=Vector3(i*10,0,0)
  box(world,base+Vector3(0,-.5,0),Vector3(6,1,12))
  var rise:=.6 if i==2 else .25
  box(world,base+Vector3(0,rise*.5,-3),Vector3(6,rise,5))
  if i<2:
   var underside:=1.95 if i==0 else 1.8
   box(world,base+Vector3(0,underside+.25,-1),Vector3(6,.5,10))
  actors.append(actor(world,base+Vector3(0,.025,.3)))
 for frame in 20:
  await physics_frame
  for a in actors:a.simulate(Vector2.ZERO,0,false,1.0/original_hz)
 for frame in original_hz:
  await physics_frame
  for a in actors:a.simulate(Vector2(0,-1),0,true,1.0/original_hz)
 check(actors[0].position.z<-2 and actors[0].position.y>.2,"Small riser fits below ceiling that blocks full maximum lift")
 check(actors[1].position.z>-.6,"Insufficient headroom remains blocking")
 check(actors[2].position.z>-.6 and actors[2].position.y<.1,"A 0.6 m ledge cannot be ratcheted above 0.55 m step limit")
 world.free();await physics_frame
 world=Node3D.new();root.add_child(world)
 box(world,Vector3(0,-.5,0),Vector3(8,1,12))
 box(world,Vector3(0,.25,-2),Vector3(4,.5,3))
 var a=actor(world,Vector3(0,.025,0))
 for frame in 15:await physics_frame;a.simulate(Vector2.ZERO,0,false,1.0/original_hz)
 var found:=false
 for frame in 120:
  await physics_frame;a.simulate(Vector2(0,-.1),0,false,1.0/original_hz)
  if a.stepped_last_frame:found=true;break
 check(found and a.is_supported(),"Capsule edge contact retains grounded state")
 await physics_frame;a.simulate(Vector2(0,-.1),0,false,1.0/original_hz,true)
 check(a.velocity.y>7 and not a.stepped_last_frame,"Fresh jump from a tread edge is not cancelled by stepping")
 a.reset_view();check(not a.stepped_last_frame,"Respawn/teleport clears remembered step support")
 world.free()
 await check_solstice()
 print("STAIR_CONTACT_RESULT ",JSON.stringify({"failures":failures,"metrics":metrics}))
 quit(0 if failures.is_empty() else 1)

func check_solstice() -> void:
 var maps=preload("res://deathmatch/maps/loader.gd")
 var entries: Array=maps.catalog().filter(func(row):return row.id=="lqdm1")
 if entries.is_empty():
  print("SKIP Solstice traversal: install the base assets to run map regressions")
  return
 var scene: PackedScene=maps.scene(entries[0])
 if not scene:check(false,"Solstice collision scene loads");return
 var level=scene.instantiate();root.add_child(level)
 # Real tread boundaries found in Solstice, exercised with the same slow,
 # oblique input that stalled the original capsule stepping code.
 var starts=[Vector3(-5.5,-.975,-28.62),Vector3(-3.75,-.475,-29.62),Vector3(28.62,.025,-25),Vector3(29.62,.525,-25),Vector3(24.5,-.975,-18.62),Vector3(35.38,3.025,-17)]
 var directions=[Vector2(0,-1),Vector2(0,-1),Vector2(1,0),Vector2(1,0),Vector2(0,-1),Vector2(-1,0)]
 var actors: Array=[]
 var delta:=1.0/Engine.physics_ticks_per_second
 for start in starts:
  var a=actor(level,start);a.collision_mask=1;actors.append(a)
 for frame in 20:
  await physics_frame
  for a in actors:a.simulate(Vector2.ZERO,0,false,delta)
 for frame in 5*Engine.physics_ticks_per_second:
  await physics_frame
  for i in actors.size():actors[i].simulate(directions[i].rotated(deg_to_rad(55))*.1,0,true,delta)
 for i in actors.size():
  var motion: Vector3=actors[i].position-starts[i]
  var progress:=Vector2(motion.x,motion.z).dot(directions[i])
  check(progress>.8,"Solstice slow oblique ascent at "+str(starts[i]))
  metrics.append({"map":"lqdm1","start":str(starts[i]),"end":str(actors[i].position),"progress":progress})
 level.free()
