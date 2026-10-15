extends SceneTree
const Destruction=preload("res://tools/voxel_battle/destruction.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
class Game extends Node3D:
 var active:=true
 var map_epoch:=7
 var resident=null
class World extends Node3D:
 var layout:Dictionary={"boxes":[]}
 var wall_bodies:Dictionary={}
 var structures=null
var server:=false
var service
var world
func arg(key:String,default_value:String)->String:
 var args:=OS.get_cmdline_user_args();var at:int=args.find(key);return args[at+1] if at>=0 and at+1<args.size() else default_value
func _initialize()->void:run.call_deferred()
func run()->void:
 server=arg("--role","client")=="server"
 var peer:=ENetMultiplayerPeer.new();var port:int=int(arg("--port","28837"))
 var error:int=peer.create_server(port,4) if server else peer.create_client("127.0.0.1",port)
 assert(error==OK);get_multiplayer().multiplayer_peer=peer
 var game:=Game.new();game.name="Game";root.add_child(game)
 world=World.new();world.name="World";game.add_child(world)
 world.layout.boxes=[{"kind":0,"center":Vector3(0,1.85,0),"size":Vector3(8.4,3.5,.24)}]
 var body:=StaticBody3D.new();body.position=Landscape.CENTERS[0]+Vector3(0,1.85,0)
 var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(8.4,3.5,.24);collider.shape=shape;body.add_child(collider);world.add_child(body);world.wall_bodies[0]=body
 service=Destruction.new();service.name="Destruction";game.add_child(service);service.setup(game,world,false,server)
 if server:
  await create_timer(3.).timeout
  service.impact(Landscape.CENTERS[0]+Vector3(0,1,.13),120,5)
  await create_timer(6.).timeout
  print("DESTRUCTION_NET_SERVER ",JSON.stringify({"broken":service.broken.keys(),"revision":service.revision}));game.queue_free();await process_frame;peer.close();quit(0);return
 var deadline:int=Time.get_ticks_msec()+6500
 while Time.get_ticks_msec()<deadline and (not service.synced or service.broken.is_empty()):await process_frame
 await physics_frame;await physics_frame
 var a:Vector3=Landscape.CENTERS[0]+Vector3(0,1,2);var b:Vector3=Landscape.CENTERS[0]+Vector3(0,1,-2)
 var clear:bool=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1)).is_empty()
 var ok:bool=service.synced and service.enabled and service.broken.size()==1 and clear
 print("DESTRUCTION_NET_CLIENT ",JSON.stringify({"label":arg("--label","early"),"synced":service.synced,"enabled":service.enabled,"broken":service.broken.keys(),"revision":service.received_revision,"passage_clear":clear,"ok":ok}))
 game.queue_free();await process_frame;peer.close();quit(0 if ok else 1)
