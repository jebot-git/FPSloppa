extends SceneTree
const Contents=preload("res://deathmatch/maps/contents.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures:Array=[]
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
 var maps=preload("res://deathmatch/maps/loader.gd").catalog()
 var water_maps:=0
 for map in maps:
  var content=Contents.new()
  check(content.open(map.path),map.id+" loads bounded BSP contents")
  if not -3 in content.leaves:continue
  var bytes=FileAccess.get_file_as_bytes(map.path);var version=bytes.decode_u32(0)
  var stride:=28 if version==29 else 44 if version==0x32505342 else 32
  var offset=bytes.decode_u32(84);var length=bytes.decode_u32(88);var found:=false
  for at in range(offset,offset+length,stride):
   if bytes.decode_s32(at)!=-3:continue
   var lo:=Vector3.ZERO;var hi:=Vector3.ZERO
   for axis in 3:
    lo[axis]=bytes.decode_s16(at+8+axis*2) if version!=0x32505342 else bytes.decode_float(at+8+axis*4)
    hi[axis]=bytes.decode_s16(at+14+axis*2) if version!=0x32505342 else bytes.decode_float(at+20+axis*4)
   var p=(lo+hi)*.5;var point=Vector3(-p.y,p.z,-p.x)/32.0
   if content.at(point)==-3:found=true;break
  check(found,map.id+" recognises actual water leaf without imported Areas")
  water_maps+=1
 check(water_maps>0,"Installed maps exercise real swimmable water")
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
 game.start_host("Water test",0,100,30,true,"dm");Fixture.setup(game)
 var runtime=preload("res://deathmatch/maps/runtime.gd").new();game.add_child(runtime);runtime.game=game;runtime.set_physics_process(false)
 runtime.has_contents=true;runtime.contents.planes.assign([Plane(Vector3.UP,1.8)]);runtime.contents.nodes.assign([Vector3i(0,-1,-2)]);runtime.contents.leaves=PackedInt32Array([-1,-3])
 var actor=game.fighters[1];actor.position=Vector3.ZERO;game.players[1].invulnerable=0;game.players[1].xr={}
 runtime._physics_process(.1)
 check(actor.in_water and actor.underwater and actor.air_left<12,"Waist and head contents enter swim and underwater state immediately")
 var hp:int=game.players[1].hp
 for i in 13:game.clock+=1;runtime._physics_process(1)
 check(game.players[1].hp<hp and actor.air_left==0,"Server applies drowning damage after air expires")
 actor.position.y=1.2;runtime._physics_process(.1)
 check(not actor.underwater and actor.air_left==12,"Surfacing restores air before leaving water entirely")
 actor.position.y=3;runtime._physics_process(.1)
 check(not actor.in_water and not actor.underwater,"Leaving water clears all submerged state")
 game.disconnect_game("Water checks complete");game.free()
 print("WATER_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
