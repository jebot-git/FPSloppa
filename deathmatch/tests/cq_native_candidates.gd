extends SceneTree
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const NativeLandscape=preload("res://tools/voxel_battle/native_landscape.gd")
const Structures=preload("res://tools/streamed_heightfield/structures.gd")
const GrassAudio=preload("res://tools/voxel_battle/grass_audio.gd")
const Prediction=preload("res://deathmatch/movement/prediction.gd")
const Fighter=preload("res://deathmatch/fighter.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures:Array=[]
var checks:=0
var measurements:Dictionary={}
class GrassFixture extends RefCounted:
 var tiles:Dictionary={}
 var native_world
class MapFixture extends RefCounted:
 var grass
class ArenaFixture extends Node3D:
 var headless:=false
 var active:=true
 var battle_map
 var fighters:Dictionary={}
 var players:Dictionary={}
 var clock:=0.
 var camera:Camera3D
 func is_vr()->bool:return false
class Walker extends Node3D:
 var local_player:=true
 var visual_grounded:=true
 var stance:="stand"
 func is_supported()->bool:return visual_grounded
class RustleProbe extends GrassAudio:
 var events:Array=[]
 func emit_rustle(point:Vector3,prone:bool=false)->void:events.append([point,prone])
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func vegetation()->void:
 var source=NativeLandscape.new();var kernel=source.native_world
 check(kernel!=null,"native world available")
 var rng:=RandomNumberGenerator.new();rng.seed=38151
 var tree_error:=0.;var grass_error:=0.;var reference_us:=0;var native_us:=0
 var coordinates:Array=[Vector2i.ZERO,Vector2i(88,88),Vector2i(44,44),Vector2i(12,35),Vector2i(24,68),Vector2i(68,22),Vector2i(-1,-1)]
 for i in 45:coordinates.append(Vector2i(rng.randi_range(0,88),rng.randi_range(0,88)))
 for coord in coordinates:
  var samples:PackedVector4Array=kernel.terrain_samples(coord,65);var heights:=PackedFloat32Array();heights.resize(samples.size())
  for i in samples.size():heights[i]=samples[i].x
  var begin:=Time.get_ticks_usec();var old_trees:=Landscape.features(coord);var old_grass:=Landscape.grass_features(coord,heights);reference_us+=Time.get_ticks_usec()-begin
  begin=Time.get_ticks_usec();var trees:Array=kernel.vegetation_trees(coord);var grass:PackedVector4Array=kernel.vegetation_grass(coord,heights);native_us+=Time.get_ticks_usec()-begin
  check(trees.size()==old_trees.size(),"tree candidate density "+str(coord))
  for i in mini(trees.size(),old_trees.size()):
   check(trees[i].kind==old_trees[i].kind and trees[i].scale==old_trees[i].scale and trees[i].angle==old_trees[i].angle,"tree seeded type/rotation/scale %s:%d"%[coord,i])
   tree_error=maxf(tree_error,trees[i].position.distance_to(old_trees[i].position))
  check(grass.size()==old_grass.size(),"grass candidate density "+str(coord))
  for i in mini(grass.size(),old_grass.size()):grass_error=maxf(grass_error,(grass[i]-old_grass[i]).length())
  check(kernel.vegetation_trees(coord)==trees and kernel.vegetation_grass(coord,heights)==grass,"repeatable tile RNG "+str(coord))
 check(tree_error<.01,"tree placement error "+str(tree_error))
 check(grass_error<.001,"grass placement error "+str(grass_error))
 check(kernel.vegetation_grass(Vector2i.ZERO,PackedFloat32Array()).is_empty(),"reject incomplete height tile")
 var thread:=Thread.new();thread.start(func():return kernel.vegetation_trees(Vector2i(12,35)))
 check(thread.wait_to_finish()==kernel.vegetation_trees(Vector2i(12,35)),"immutable vegetation sampling on worker")
 measurements.vegetation={"tiles":coordinates.size(),"tree_max_error":tree_error,"grass_max_error":grass_error,"reference_mean_us":reference_us/float(coordinates.size()),"native_mean_us":native_us/float(coordinates.size())}
func buildings()->void:
 var actual:=Structures.new();var reference:=Structures.new();reference.native_world=null
 var meshes:Array=[]
 for k in 4:
  var levels:Array=[]
  for lod in 3:
   var b:=Structures.Builder.new();b.box(Vector3(0,4,0),Vector3(20+k*3,8,30),Color.WHITE);levels.append(b.finish())
  meshes.append(levels)
 var sites:Array=[]
 for i in 64:sites.append({"kind":i%4,"position":Vector3((i%8-4)*95,0,(i/8-4)*95)})
 actual.meshes=meshes;reference.meshes=meshes;actual.placements=sites;reference.placements=sites
 root.add_child(actual);root.add_child(reference);actual.setup();reference.setup()
 var camera:=Camera3D.new();root.add_child(camera);camera.far=1200
 var native_us:=0;var reference_us:=0
 for step in 100:
  camera.position=Vector3(sin(step*.24)*500,2,cos(step*.17)*500);camera.rotation=Vector3(0,step*.21,0)
  for node in [reference,actual]:node.force_near=step%5==0;node.culling_enabled=step%3!=0;node.view_distance=250 if step%7==0 else 550
  var begin:=Time.get_ticks_usec();reference.update(camera);reference_us+=Time.get_ticks_usec()-begin
  begin=Time.get_ticks_usec();actual.update(camera);native_us+=Time.get_ticks_usec()-begin
  check(actual.counts==reference.counts and actual.visible_sites==reference.visible_sites and actual.triangles==reference.triangles,"building visibility and hysteresis %d"%step)
  for k in meshes.size():
   for lod in 3:
    for i in reference.counts[k][lod]:check(actual.groups[k][lod].multimesh.get_instance_transform(i).is_equal_approx(reference.groups[k][lod].multimesh.get_instance_transform(i)),"building packed transform")
 # Destruction changes near bounds/counts and restores them on round reset.
 var b:=Structures.Builder.new();b.box(Vector3(0,2,0),Vector3(4,4,4),Color.WHITE)
 var replacement:=b.finish()
 for node in [reference,actual]:
  node.meshes[0]=[replacement,replacement,replacement];node.refresh_native_meshes();node.reset_lods();node.last_position=Vector3.INF
 camera.position=Vector3(0,2,50);camera.rotation=Vector3.ZERO
 reference.update(camera);actual.update(camera)
 check(actual.counts==reference.counts and actual.triangles==reference.triangles,"destruction mesh-cache refresh and LOD reset")
 actual.free();reference.free();camera.free()
 measurements.buildings={"sites":64,"reference_mean_us":reference_us/100.,"native_mean_us":native_us/100.}
func grass_audio()->void:
 var game:=ArenaFixture.new();root.add_child(game);game.camera=Camera3D.new();game.add_child(game.camera)
 game.battle_map=MapFixture.new();game.battle_map.grass=GrassFixture.new();var grass=game.battle_map.grass
 grass.native_world=preload("res://deathmatch/native/world.gd").create()
 var rows:=PackedVector4Array()
 for z in range(-12,13):
  for x in range(-12,13):rows.append(Vector4(x*.8,0,z*.8,0))
 # Tile seam coverage and negative audio cell coordinates.
 for coord in [Vector2i(44,44),Vector2i(43,44)]:
  grass.tiles[coord]={"rows":rows};var kinds:=PackedByteArray();kinds.resize(rows.size())
  grass.native_world.grass_load(coord,rows,kinds,AABB(Vector3(-20,-1,-20),Vector3(40,2,40)))
 var actual:=RustleProbe.new();var reference:=RustleProbe.new();reference.native_audio=null;actual.game=game;reference.game=game;game.add_child(actual);game.add_child(reference)
 actual.set_process(false);reference.set_process(false)
 for i in 1200:
  var p:=Vector3(sin(i*.71)*16,(-1.5 if i%9==0 else 1.5 if i%11==0 else 0.),cos(i*.37)*16)
  check(actual.contains(p)==reference.contains(p),"cached grass proximity %d"%i)
 for id in 64:
  var actor:=Walker.new();game.add_child(actor);game.fighters[id]=actor;game.players[id]={"dead":false,"spectator":false,"slow":false}
 var native_us:=0;var reference_us:=0
 for step in 180:
  game.clock=step*.11
  for id in game.fighters:
   var actor=game.fighters[id];actor.position=Vector3(fmod(step*.45+id*.1,18)-9,0,(id%9)-4)
   actor.stance="prone" if id%3==0 else "stand";actor.visual_grounded=step%19!=0
   game.players[id].dead=id%7==0;game.players[id].spectator=id%11==0;game.players[id].slow=step%13==0
  var begin:=Time.get_ticks_usec();reference._update(.11);reference_us+=Time.get_ticks_usec()-begin
  begin=Time.get_ticks_usec();actual._update(.11);native_us+=Time.get_ticks_usec()-begin
  check(actual.events==reference.events,"rustle eligibility/cadence %d"%step)
  if step==80:
   game.fighters[2].free();game.fighters.erase(2);game.players.erase(2)
  if step==100:actual.set_enabled(false);reference.set_enabled(false);actual.set_enabled(true);reference.set_enabled(true)
 check(not actual.events.is_empty(),"rustle fixture emits audio events")
 for coord in grass.tiles.keys():grass.native_world.grass_evict(coord)
 grass.tiles.clear();check(not actual.contains(Vector3.ZERO) and not reference.contains(Vector3.ZERO),"evicted grass makes no sound")
 measurements.grass_audio={"actors":64,"events":actual.events.size(),"reference_mean_us":reference_us/180.,"native_mean_us":native_us/180.}
 game.free()
func spatial_audio()->void:
 var world:=Node3D.new();root.add_child(world);Fixture.box(world,Vector3(0,0,-3),Vector3(4,4,.5));await physics_frame;await physics_frame
 var kernel=preload("res://deathmatch/native/audio.gd").create();check(kernel!=null,"native audio available")
 var open:=AudioStreamPlayer3D.new();var blocked:=AudioStreamPlayer3D.new();var expired:=AudioStreamPlayer3D.new();var freed:=AudioStreamPlayer3D.new()
 for player in [open,blocked,expired,freed]:world.add_child(player);player.set_meta("dry_db",-8.);player.set_meta("expires",10.)
 open.position=Vector3(0,0,2);blocked.position=Vector3(0,0,-6);expired.set_meta("expires",.5)
 var sources:Array=[open,blocked,expired,freed];freed.free()
 var live:Array=kernel.spatial_step(sources,world.get_world_3d(),Vector3.ZERO,1.)
 check(live==[open,blocked] and expired.is_queued_for_deletion(),"spatial expiry and stale ObjectID pruning")
 check(open.volume_db==-8. and open.attenuation_filter_cutoff_hz==18000.,"unobstructed source dry volume")
 check(blocked.volume_db==-18. and blocked.attenuation_filter_cutoff_hz==1800.,"blocked source attenuation and lowpass")
 check(kernel.get_source_updates()==2,"spatial source telemetry")
 var space:=world.get_world_3d()
 var thread:=Thread.new();thread.start(func():return kernel.spatial_step([open],space,Vector3.ZERO,1.))
 check(thread.wait_to_finish().is_empty() and kernel.get_source_updates()==2,"audio rejects foreign-thread scene updates")
 check(is_equal_approx(kernel.room_target(world.get_world_3d(),Vector3.ZERO),.072),"room probe matches single wall")
 check(not kernel.occluded(world.get_world_3d(),Vector3.ZERO,Vector3(0,0,.1)),"coincident ray suppression")
 # Exercise the actual script adapter with its reference backend on the same world.
 var game:=ArenaFixture.new();world.add_child(game);game.camera=Camera3D.new();game.add_child(game.camera);game.clock=1.
 var adapter=load("res://deathmatch/audio/spatial.gd").new();var reference_adapter=load("res://deathmatch/audio/spatial.gd").new();reference_adapter.native_audio=null
 world.add_child(adapter);world.add_child(reference_adapter)
 for item in [adapter,reference_adapter]:item.game=game;item.set_process(false);item.set_physics_process(false)
 var source_pairs:Array=[]
 for i in 32:
  var pair:Array=[]
  for item in [reference_adapter,adapter]:
   var player:=AudioStreamPlayer3D.new();world.add_child(player);player.position=Vector3(i%8-4,0,-6 if i%2==0 else 2);player.set_meta("dry_db",-8.);player.set_meta("expires",100.)
   item.active.append(player);pair.append(player)
  source_pairs.append(pair)
 var native_us:=0;var reference_us:=0
 for step in 100:
  game.camera.position.x=sin(step*.2)*5
  var begin:=Time.get_ticks_usec();reference_adapter._physics_process(.11);reference_us+=Time.get_ticks_usec()-begin
  begin=Time.get_ticks_usec();adapter._physics_process(.11);native_us+=Time.get_ticks_usec()-begin
  for pair in source_pairs:check(pair[0].volume_db==pair[1].volume_db and pair[0].attenuation_filter_cutoff_hz==pair[1].attenuation_filter_cutoff_hz,"spatial adapter source parity")
 check(adapter.source_updates==reference_adapter.source_updates and adapter.active.size()==32,"spatial adapter telemetry and live sources")
 measurements.spatial_audio={"sources":32,"reference_mean_us":reference_us/100.,"native_mean_us":native_us/100.}
 world.free();await process_frame
func prediction()->void:
 var world:=Node3D.new();root.add_child(world)
 var actual:=Fighter.new();var reference:=Fighter.new();world.add_child(actual);world.add_child(reference)
 actual.set_process(false);reference.set_process(false);actual.prediction=Prediction.new();reference.prediction=Prediction.new();reference.prediction.native_motion=null
 var rng:=RandomNumberGenerator.new();rng.seed=37811
 var native_us:=0;var reference_us:=0
 for i in 1200:
  var pos:=Vector3(rng.randf_range(-3,3),rng.randf_range(-2,2),0);var vel:=Vector3(rng.randf_range(-8,8),rng.randf_range(-8,8),0)
  var height:=1.1 if i%3==0 else 1.65;var jet:Dictionary={"energy":rng.randf(),"nested":{"x":i}}
  actual.prediction.remember(i,pos,vel,height,jet,.3);reference.prediction.remember(i,pos,vel,height,jet,.3);jet.nested.x=-1
  if i%6!=0:continue
  for actor in [reference,actual]:actor.position=Vector3(0,2,0);actor.velocity=Vector3(4,2,1)
  var sequence:=i-3;var server_pos:=pos+Vector3(.3 if i%12==0 else 0,0,0);var grounded:=i%5==0
  var begin:=Time.get_ticks_usec();reference.prediction.reconcile(reference,sequence,server_pos,vel,height,grounded);reference_us+=Time.get_ticks_usec()-begin
  begin=Time.get_ticks_usec();actual.prediction.reconcile(actual,sequence,server_pos,vel,height,grounded);native_us+=Time.get_ticks_usec()-begin
  check(actual.position.is_equal_approx(reference.position) and actual.velocity.is_equal_approx(reference.velocity),"prediction corrections %d"%i)
  check(actual.prediction.samples==reference.prediction.samples and actual.prediction.acknowledged==reference.prediction.acknowledged,"pending history shift/pruning %d"%i)
  check(actual.prediction.stats==reference.prediction.stats,"prediction statistics %d"%i)
 for actor in [reference,actual]:
  actor.prediction.clear()
  for i in 240:actor.prediction.remember(i,Vector3.ZERO,Vector3.ZERO)
  actor.prediction.remember(100,Vector3.ONE,Vector3.ONE)
 check(actual.prediction.samples==reference.prediction.samples and actual.prediction.samples.size()==180,"bounded duplicate insertion order")
 actual.prediction.reconcile(actual,2000,Vector3.ZERO,Vector3.ZERO);reference.prediction.reconcile(reference,2000,Vector3.ZERO,Vector3.ZERO)
 check(actual.position==reference.position and actual.prediction.samples==reference.prediction.samples,"missing history reset")
 actual.prediction.stats={"corrections":0,"resets":0,"max_error":0.};reference.prediction.stats={"corrections":0,"resets":0,"max_error":0.}
 check(actual.prediction.stats==reference.prediction.stats,"diagnostic statistics reset compatibility")
 var dense_native_us:=0;var dense_reference_us:=0
 for round_index in 400:
  for actor in [reference,actual]:
   actor.prediction.clear();actor.position=Vector3.ZERO;actor.velocity=Vector3.ZERO
   for seq in 180:actor.prediction.remember(seq,Vector3.ZERO,Vector3.ZERO)
  var begin:=Time.get_ticks_usec();reference.prediction.reconcile(reference,0,Vector3(.4,0,0),Vector3(2,0,0));dense_reference_us+=Time.get_ticks_usec()-begin
  begin=Time.get_ticks_usec();actual.prediction.reconcile(actual,0,Vector3(.4,0,0),Vector3(2,0,0));dense_native_us+=Time.get_ticks_usec()-begin
  check(actual.prediction.samples==reference.prediction.samples,"full pending-history correction %d"%round_index)
 measurements.prediction={"full_history_reference_mean_us":dense_reference_us/400.,"full_history_native_mean_us":dense_native_us/400.,"reconciliations":200,"reference_mean_us":reference_us/200.,"native_mean_us":native_us/200.}
 world.free()
func run()->void:
 vegetation();buildings();grass_audio();await spatial_audio();prediction()
 print("CQ_NATIVE_CANDIDATES ",JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements}))
 quit(0 if failures.is_empty() else 1)
