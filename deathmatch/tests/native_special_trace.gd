extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Hit=preload("res://deathmatch/hit_detection.gd")
var g
var checks:=0
var failures:Array=[]
var rng:=RandomNumberGenerator.new()
func check(ok:bool,label:String):
 checks+=1
 if not ok and failures.size()<20:failures.append(label);push_error(label)
func compare(start:Vector3,end:Vector3,radius:float=0.,rewind:float=0.,exclude:int=1):
 var context:Dictionary=g._rewind_context(rewind)
 var a:Dictionary=g._trace_reference(start,end,exclude,rewind,radius,{},null,context)
 var b:Dictionary=g._trace(start,end,exclude,rewind,radius,{},null,context)
 check(a.keys()==b.keys(),"trace field/order parity "+str(a)+" / "+str(b))
 for key in a:
  check(a[key].distance_to(b.get(key,Vector3.INF))<.0002 if a[key] is Vector3 else a[key]==b.get(key),"trace "+str(key)+" parity")
 return b
func _initialize():run.call_deferred()
func run():
 rng.seed=20261001
 g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
 g.start_host("Native special parity",0,100,30,true,"tf","quake");g.set_process(false);g.set_physics_process(false)
 if g.bots:g.bots.free();g.bots=null
 check(g.native_projectiles!=null and g.native_projectiles.has_method("trace_structures"),"updated native special trace loaded")
 if failures.size():g.free();quit(1);return
 var tf=g.match_mode.fortress;tf.buildings.clear()
 for id in g.players:
  g.players[id].dead=false;g.players[id].spectator=false;g.players[id].invulnerable=0;g.players[id].hp=10000
  g.fighters[id].position=Fixture.point(id*2,-8)
 for i in 32:tf.buildings[str(i)]={"position":Fixture.point((i%8-4)*1.5,-2.-i/8*2)}
 for i in 3000:
  var start:=Fixture.point(rng.randf_range(-10,10),rng.randf_range(-10,3))+Vector3.UP*rng.randf_range(0,3)
  var end:=Fixture.point(rng.randf_range(-10,10),rng.randf_range(-10,3))+Vector3.UP*rng.randf_range(0,3)
  var radius:float=[0.,.14,.3][i%3];var limit:float=INF if i%2 else rng.randf_range(0,1)
  var a:Dictionary=tf.trace(start,end,limit,radius);var b:Dictionary=g.native_projectiles.trace_structures(tf.buildings,start,end,limit,radius)
  check(a.is_empty()==b.is_empty(),"structure hit/miss")
  if not a.is_empty():check(a.key==b.get("key") and absf(a.fraction-b.get("fraction",INF))<.0001,"structure nearest fraction and stable identity")
 g.clock=10.
 for i in 12:g.clock+=1./60.;g._record_history()
 await physics_frame;await physics_frame
 for mode in ["tf","as","tb"]:
  g.match_mode.kind=mode;check(g._native_trace_allowed(),"native enabled for "+mode)
  for i in 120:
   compare(Fixture.point(rng.randf_range(-8,8),2)+Vector3.UP,Fixture.point(rng.randf_range(-8,8),-12)+Vector3.UP,[0.,.14,.3][i%3],.1 if i%2 else 0.)
 # Removal between rays must not leave a cached structure target.
 g.match_mode.kind="tf";tf.buildings={"front":{"position":Fixture.point(0,-2)},"back":{"position":Fixture.point(0,-4)}}
 var hit:Dictionary=compare(Fixture.point()+Vector3.UP,Fixture.point(0,-6)+Vector3.UP)
 check(hit.get("building")=="front","first structure occludes second")
 tf.buildings.erase("front");hit=compare(Fixture.point()+Vector3.UP,Fixture.point(0,-6)+Vector3.UP)
 check(hit.get("building")=="back","destruction visible to next pellet")
 tf.buildings.clear()
 # Real BA2 physics hull, not a body proxy. Mounted actor is placed away from it
 # so native/reference must both exclude that exposed placeholder body.
 var w=tf.walkers;w.configure([{"id":"native_test","team":0,"points":[Fixture.point(0,-8),Fixture.point(0,-20)]}])
 w.robots.native_test.pilot=-1;g.fighters[-1].position=Fixture.point(0,-2)
 await physics_frame;await physics_frame
 var hull_hits:=0
 for height in [1.,3.,5.,7.,9.]:
  for radius in [0.,.14,.3]:
   hit=compare(Fixture.point()+Vector3.UP*height,Fixture.point(0,-18)+Vector3.UP*height,radius)
   if hit.get("vehicle",false):hull_hits+=1
 check(hull_hits>0,"actual mounted hull attributed to pilot")
 g.players[-1].dead=true;compare(Fixture.point()+Vector3.UP*5,Fixture.point(0,-18)+Vector3.UP*5)
 g.players[-1].dead=false;w.robots.native_test.pilot=0;compare(Fixture.point()+Vector3.UP,Fixture.point(0,-18)+Vector3.UP)
 w.reset()
 # Live Tribes overlays preserve their ordering and specialized identities.
 g.match_mode.kind="st";g.armory.select("tribes")
 var tribes=g.match_mode.tribes
 for id in g.players:g.fighters[id].position=Fixture.point(25+id,20)
 tribes.deployables.rows[1]={"kind":"turret","position":Fixture.point(0,-4),"normal":Vector3.UP,"yaw":0.}
 tribes.targeting.beacons[1]={"position":Fixture.point(0,-2)+Vector3.UP}
 g.projectiles[999]={"weapon":10,"stuck":true,"position":Fixture.point(0,-3)+Vector3.UP,"node":null}
 tribes.combat.mines[999]=true
 await physics_frame
 hit=compare(Fixture.point()+Vector3.UP,Fixture.point(0,-8)+Vector3.UP)
 check(hit.has("beacon"),"beacon before mine and deployable")
 tribes.targeting.beacons.clear();hit=compare(Fixture.point()+Vector3.UP,Fixture.point(0,-8)+Vector3.UP)
 check(hit.has("mine"),"mine before deployable")
 g.projectiles.erase(999);tribes.combat.mines.clear();hit=compare(Fixture.point()+Vector3.UP,Fixture.point(0,-8)+Vector3.UP)
 check(hit.has("deployable"),"deployable target identity")
 for i in 200:compare(Fixture.point(rng.randf_range(-4,4),2)+Vector3.UP*rng.randf_range(.1,2),Fixture.point(rng.randf_range(-4,4),-8)+Vector3.UP,[0.,.14,.3][i%3])
 tribes.deployables.rows.clear();tribes.targeting.beacons.clear()
 var vehicles=tribes.vehicles
 for kind in ["scout","lpc","hpc"]:
  vehicles.rows[444]={"kind":kind,"position":Fixture.point(0,-6)+Vector3.UP,"yaw":.35}
  hit=compare(Fixture.point()+Vector3.UP,Fixture.point(0,-14)+Vector3.UP,.14)
  check(hit.get("scout",0)==444,"Tribes "+kind+" hull identity")
  vehicles.rows.clear()
 var pads=tribes.stations()
 check(pads!=null,"station overlay fixture available")
 if pads:
  var old_generators:Array=pads.generators;var old_assets:Array=pads.assets.rows;var old_defences:Array=pads.defences.rows
  var center:Vector3=Fixture.point(0,-6)+Vector3.UP
  var cover=Fixture.box(g,center,Vector3(2,2,1))
  await physics_frame;await physics_frame
  for feature in ["generator","base_asset","fixed_turret"]:
   pads.generators=[];pads.assets.rows=[];pads.defences.rows=[]
   if feature=="generator":pads.generators=[{"frame":Transform3D(Basis.IDENTITY,center),"team":1,"key":7}]
   elif feature=="base_asset":pads.assets.rows=[{"frame":Transform3D(Basis.IDENTITY,center),"parts":[[Vector3.ZERO,Vector3(2,2,1)]]}]
   else:pads.defences.rows=[{"kind":"fusion","position":Fixture.point(0,-6)}]
   hit=compare(Fixture.point()+Vector3.UP,Fixture.point(0,-14)+Vector3.UP,0.)
   compare(Fixture.point()+Vector3.UP,Fixture.point(0,-14)+Vector3.UP,.14)
   check(hit.has(feature),"native station overlay "+feature)
  pads.generators=old_generators;pads.assets.rows=old_assets;pads.defences.rows=old_defences
  cover.free()
 # Shootable areas retain their map-node identity and override body attribution.
 var runtime=g.get_node_or_null("Map/MapRuntime")
 if runtime:
  runtime.set_physics_process(false)
  var area:=Area3D.new();area.collision_layer=1;area.collision_mask=0
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1,2,1);shape.shape=box;area.add_child(shape)
  g.add_child(area);area.position=Fixture.point(6,-2)+Vector3.UP;runtime.triggers.rows[area]={}
  await physics_frame;await physics_frame
  for radius in [0.,.14]:
   hit=compare(Fixture.point(6,0)+Vector3.UP,Fixture.point(6,-8)+Vector3.UP,radius)
   check(hit.get("map_node")==area and hit.id==0,"shootable area identity preserved")
  runtime.triggers.rows.erase(area);area.free()
 g.disconnect_game();g.free();await process_frame
 print("NATIVE_SPECIAL_TRACE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
