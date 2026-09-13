extends SceneTree
var game
var rows:Array=[]
func _initialize():run.call_deferred()
func q(x:float,y:float,z:float=0)->Vector3:return Vector3(-y*1.3,z,-x*1.6)/32+Vector3.UP*.05
func run():
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.selected_map="as_frigate";game.start_host("Water entrance test",0,100000,60,true,"as","ut99")
 game.set_process(false);game.set_physics_process(false);game.dedicated=true
 for id in game.players:game.players[id].spectator=id!=-1;game.players[id].team=0;game._spawn(id)
 while not game.bots.navigation.ready():await physics_frame
 game.bots.navigation.install_links()
 for i in 120:game.bots.navigation.update_jump_links();await physics_frame
 var routes={"intake":[q(672,384,-192),q(672,288,-192),q(752,176,-128),q(352,192,0),q(288,192,0)],"harbor_escape":[q(1512,-928,-192),q(1312,-928,-32),q(1216,-928,0)]}
 for name_here in routes:
  for control in ["direct","ai"]:
   game.get_node("Map/MapRuntime").set_physics_process(control=="ai")
   var points:Array=routes[name_here];game._spawn(-1)
   var actor=game.fighters[-1];actor.position=points[0];actor.velocity=Vector3.ZERO;actor.reset_view()
   game.bots.brains[-1]=game.bots.new_brain(-1)
   var brain:Dictionary=game.bots.brains[-1];var state:Dictionary=game.players[-1]
   var segments:Array=[];var water_seconds:=0.0
   for target:Vector3 in points.slice(1):
    brain.goal=target;brain.goal_kind="objective";brain.goal_key="water-fixture";brain.path=game.bots.navigation.path(actor.position,target);brain.step=0
    var initial_path:PackedVector3Array=brain.path.duplicate();var start:float=game.clock;var trace:Array=[]
    while game.clock-start<20 and actor.position.distance_to(target)>.65:
     await physics_frame
     if control=="ai":
      brain.next=game.clock+100;brain.plan_at=game.clock+100;game._physics_process(1.0/60)
     else:
      game.clock+=1.0/60;game.get_node("Map/MapRuntime")._physics_process(1.0/60)
      var offset:Vector3=target-actor.position
      actor.simulate(Vector2(offset.x,offset.z).normalized(),0,true,1.0/60,false,Vector3(0,clampf(offset.y,-1,1),0))
     if actor.in_water:water_seconds+=1.0/60
     if int((game.clock-start)*60)%60==0:trace.append({"p":actor.position,"water":actor.in_water,"underwater":actor.underwater,"swim":state.swim,"goal":brain.goal,"path":brain.path})
    var passed:bool=actor.position.distance_to(target)<=.65
    segments.append({"target":target,"end":actor.position,"passed":passed,"seconds":game.clock-start,"path":initial_path,"trace":trace})
    if not passed:break
   rows.append({"route":name_here,"control":control,"passed":segments.size()==points.size()-1 and segments.all(func(r):return r.passed),"water_seconds":water_seconds,"segments":segments})
   print("WATER_RESULT ",name_here," ",control," ",rows[-1].passed)
 FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit()
