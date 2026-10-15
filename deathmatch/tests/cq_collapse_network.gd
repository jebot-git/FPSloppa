extends SceneTree
const Fixture=preload("res://deathmatch/tests/cq_collapse_fixture.gd")
func arg(key:String,fallback:String)->String:
 var args:=OS.get_cmdline_user_args();var index:=args.find(key);return args[index+1] if index>=0 and index+1<args.size() else fallback
func _initialize()->void:run.call_deferred()
func run()->void:
 var server:bool=arg("--role","client")=="server"
 var peer:=ENetMultiplayerPeer.new();var port:int=int(arg("--port","28839"))
 assert((peer.create_server(port,4) if server else peer.create_client("127.0.0.1",port))==OK)
 get_multiplayer().multiplayer_peer=peer
 var f:Dictionary=Fixture.make(root,false);var service=f.service
 service.enabled=server
 if server:
  await create_timer(2.).timeout
  service.apply_breaks(service.integrity.buildings[0].stories[0][0].cells,f.origin,false);service.revision+=1;service.publish()
  await create_timer(2.).timeout
  service.apply_breaks(Fixture.support_ids(service,0,1),f.origin,false);service.revision+=1;service.publish()
  var collapsed:bool=service.collapsed.has(0)
  await create_timer(3.).timeout
  service.clear_state();service.revision+=1;service.publish()
  await create_timer(2.).timeout
  print("CQ_COLLAPSE_NET_SERVER ",JSON.stringify({"collapsed_before_reset":collapsed,"restored":service.collapsed.is_empty(),"revision":service.revision}))
  f.game.queue_free();await process_frame;peer.close();quit(0 if collapsed else 1);return
 var deadline:int=Time.get_ticks_msec()+11000;var observed_stable:=false
 while Time.get_ticks_msec()<deadline and service.collapsed.is_empty():
  if service.synced and service.collapsed.is_empty():observed_stable=true
  await process_frame
 await physics_frame;await physics_frame
 var removed:bool=ray(f.world,f.origin+Vector3(0,12,0),f.origin+Vector3(0,1,0)).is_empty()
 var neighbour:bool=not ray(f.world,f.origin+Vector3(26,12,0),f.origin+Vector3(26,1,0)).is_empty()
 var collapsed:bool=service.collapsed.has(0) and service.received_revision==2
 var rubble_received:bool=service.rubble[0].body.collision_layer==1
 while Time.get_ticks_msec()<deadline and service.received_revision<3:await process_frame
 await physics_frame;await physics_frame
 var restored:bool=service.collapsed.is_empty() and not ray(f.world,f.origin+Vector3(0,12,0),f.origin+Vector3(0,1,0)).is_empty()
 var ok:bool=service.synced and service.enabled and collapsed and removed and neighbour and restored and rubble_received and service.rubble[0].body.collision_layer==0 and f.game.collapse_calls.is_empty() and (observed_stable or arg("--label","early")=="late")
 print("CQ_COLLAPSE_NET_CLIENT ",JSON.stringify({"label":arg("--label","early"),"observed_stable":observed_stable,"collapsed_received":collapsed,"upper_collision_removed":removed,"neighbour_retained":neighbour,"reset_restored":restored,"revision":service.received_revision,"ok":ok}))
 f.game.queue_free();await process_frame;peer.close();quit(0 if ok else 1)
func ray(world,a:Vector3,b:Vector3)->Dictionary:return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
