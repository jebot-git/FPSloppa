extends SceneTree
const Schedule=preload("res://tools/voxel_battle/weather_schedule.gd")
const Weather=preload("res://tools/voxel_battle/weather.gd")
var checks:=0
var failures:Array[String]=[]
class Clock extends RefCounted:
 var weather_flash:=0.0
 func cycle_time()->float:return 1500.
class Map extends RefCounted:
 var lighting:=Clock.new()
class Game extends Node3D:
 var active:=true
 var headless:=true
 var map_epoch:=0
 var players:Dictionary={}
 var weather
 var battle_map:=Map.new()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var seen:Dictionary={};var changes:=0;var repeats:=0
 var densities:Dictionary={}
 for seed_value in [0,1,42,29371,2147483647]:
  var offset:=Schedule.change_offset(seed_value)
  var last_change:=-Schedule.DAY_SECONDS
  for day in 1000:
   var at:=offset+day*Schedule.DAY_SECONDS
   var before:=Schedule.sample(seed_value,at-.001)
   var begin:=Schedule.sample(seed_value,at)
   var after:=Schedule.sample(seed_value,at+Schedule.TRANSITION_SECONDS)
   check(begin.previous==before.mode,"Boundary starts from preceding day")
   check(begin.values.is_equal_approx(before.values),"No discontinuity at transition start")
   check(after.values.is_equal_approx(Schedule.profile_at(seed_value,day)),"Transition reaches authored profile")
   check(Schedule.sample(seed_value,at+600.).values==Schedule.sample(seed_value,at+600.).values,"Late-join stateless result")
   seen[after.mode]=true
   if not before.values.is_equal_approx(after.values):
    check(at-last_change>=Schedule.DAY_SECONDS,"At least one full cycle between changes")
    last_change=at;changes+=1
   if before.mode==after.mode:repeats+=1
   densities[str(after.mode)+":"+str(after.values.x)+":"+str(after.values.y)]=true
   var target:Vector4=after.target
   var fog_range:Vector2=Schedule.FOG_RANGES[after.mode]
   var rain_range:Vector2=Schedule.RAIN_RANGES[after.mode]
   check(target.x>=fog_range.x-.000001 and target.x<=fog_range.y+.000001,"Random fog respects profile range")
   check(target.y>=rain_range.x-.000001 and target.y<=rain_range.y+.000001,"Random rain respects profile range")
   for step in [0.,.25,.5,.75,1.]:
    var value:Vector4=Schedule.sample(seed_value,at+step*Schedule.TRANSITION_SECONDS).values
    check(value.x>=.00005 and value.x<=.0101 and value.y>=0 and value.y<=1 and value.w>=0 and value.w<=1,"Bounded weather blend")
 check(seen.size()==4 and changes>0 and repeats>0,"Random schedule includes every weather and repeated types")
 check(densities.size()>4900,"Fog and rain density vary independently across periods")
 for second in range(0,4800):
  var event:=Schedule.lightning(42,second)
  check(event.flash>=0 and event.flash<=1.01 and event.distance>=250 and event.distance<700,"Bounded deterministic thunder")
 var budget:=Weather.new()
 for frame in 300:budget.rain_budget(.03)
 check(budget.reduced and budget.rain_budget(.03)==.4,"Sustained render pressure reduces local rain")
 for frame in 1700:budget.rain_budget(.01)
 check(not budget.reduced,"Rain detail recovers only after sustained headroom")
 budget.free()
 # Real ENet authority RPC and map-epoch/late-join seed synchronization, without graphics.
 var server:=Game.new();server.name="WeatherServer";root.add_child(server)
 var server_api:=SceneMultiplayer.new();set_multiplayer(server_api,server.get_path())
 var peer:=ENetMultiplayerPeer.new();var port:=29000+OS.get_process_id()%10000
 var error:=peer.create_server(port,4)
 check(error==OK,"Isolated server starts")
 if error==OK:
  server_api.multiplayer_peer=peer
  var weather:=Weather.new();weather.name="Weather";server.add_child(weather);weather.setup(server)
  await create_timer(.1).timeout
  var client:=Game.new();client.name="WeatherClient";root.add_child(client)
  var client_api:=SceneMultiplayer.new();set_multiplayer(client_api,client.get_path())
  var client_peer:=ENetMultiplayerPeer.new();client_peer.create_client("127.0.0.1",port);client_api.multiplayer_peer=client_peer
  var local_weather:=Weather.new();local_weather.name="Weather";client.add_child(local_weather);local_weather.setup(client)
  server_api.peer_connected.connect(func(id):server.players[id]={})
  var deadline:=Time.get_ticks_msec()+5000
  while local_weather.seed_value<0 and Time.get_ticks_msec()<deadline:await process_frame
  check(local_weather.seed_value==weather.seed_value and weather.seed_value>=0,"Late join receives authority seed")
  check(local_weather.seed_epoch==0,"Initial epoch synchronized")
  var initial_seed:int=weather.seed_value
  server.map_epoch=1;client.map_epoch=1
  deadline=Time.get_ticks_msec()+5000
  while local_weather.seed_epoch!=1 and Time.get_ticks_msec()<deadline:await process_frame
  check(local_weather.seed_epoch==1 and local_weather.seed_value==weather.seed_value,"Map epoch synchronizes seed")
  check(weather.seed_value==initial_seed,"Round epoch preserves weather schedule")
  await process_frame
  check(local_weather.state==weather.state,"Server/client derive identical weather")
  check(weather.rain==null and local_weather.rain==null,"Headless peers allocate no visual/audio effects")
  client.active=false;await process_frame;await process_frame
  check(local_weather.seed_value==-1 and local_weather.seed_epoch==-1,"Disconnect clears cached weather seed")
  client.active=true;deadline=Time.get_ticks_msec()+5000
  while local_weather.seed_epoch!=1 and Time.get_ticks_msec()<deadline:await process_frame
  check(local_weather.seed_value==weather.seed_value and local_weather.seed_epoch==1,"Reconnection fetches authority seed again")
  server.weather=weather
  weather.current_lightning=Schedule.lightning(42,1500.)
  server.battle_map.lighting.weather_flash=1.
  var vision=preload("res://deathmatch/conquest/classes/night_vision.gd").new();vision.setup(server)
  var light:Dictionary=weather.lightning_source(Vector3.ZERO)
  var gaze:=Transform3D(Basis.looking_at(light.position.normalized()),Vector3.ZERO)
  var spots:Array=vision.flash_samples(gaze,100.)
  check(spots.size()==1 and spots[0].strength>.99,"Looking at lightning produces bright NVG glare")
  var opposite:=Transform3D(Basis.looking_at(-light.position.normalized()),Vector3.ZERO)
  check(vision.flash_samples(opposite,100.05).is_empty(),"Lightning behind the visor causes no glare")
  server.battle_map.lighting.weather_flash=0.
  spots=vision.flash_samples(gaze,100.3)
  check(spots.size()==1 and spots[0].strength>0 and spots[0].strength<1,"Lightning NVG afterimage recovers gradually")
  check(vision.flash_samples(gaze,100.9).is_empty(),"Lightning NVG glare expires")
  vision.clear_local_effects()
  check(vision.flash_samples(gaze,101.).is_empty(),"Removing visor clears lightning afterimage")
  # A real occluder blocks source glare, rather than dazzling through roofs/walls.
  server.battle_map.lighting.weather_flash=1.
  var wall:=StaticBody3D.new();server.add_child(wall);wall.position=light.position.normalized()*6.
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(4,4,4);shape.shape=box;wall.add_child(shape)
  await physics_frame;await physics_frame
  check(vision.flash_samples(gaze,102.).is_empty(),"Occluded lightning does not cause direct NVG glare")
  server.battle_map.lighting.weather_flash=0.
  wall.free();vision.clear_local_effects()
  root.remove_child(client);root.remove_child(server)
  client_api.multiplayer_peer=OfflineMultiplayerPeer.new();server_api.multiplayer_peer=OfflineMultiplayerPeer.new()
  client.free();server.free()
 else:server.free()
 print("CQ_WEATHER_TEST ",JSON.stringify({"checks":checks,"failures":failures,"changes":changes,"same_type_days":repeats}))
 quit(0 if failures.is_empty() else 1)
