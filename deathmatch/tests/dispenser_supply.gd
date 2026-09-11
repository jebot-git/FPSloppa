extends SceneTree
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
 print("PASS " if value else "FAIL ",label)
 if not value:failures.append(label)
func run() -> void:
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 game.start_host("Dispenser",0,20,10,true,"tf")
 var tf=game.match_mode.fortress;var point:=Vector3(1000,10,1000)
 for id in game.players:game.fighters[id].position=point+Vector3(10,0,0);game.players[id].team=1
 game.players[1].team=0;game.players[1].tf_class="engineer"
 tf.buildings={1:{"owner":1,"team":0,"position":point,"kind":"dispenser","hp":150,"ready":0.0,"next":0.0,"expires":9999.0}}
 var s: Dictionary=game.players[-1];s.team=0;s.dead=false;s.spectator=false;game.fighters[-1].position=point+Vector3(1,0,0)
 for role in tf.CLASSES:
  s.tf_class=role;s.hp=20;s.armor=0;s.ammo=[0,0,0,0];s.owned=tf.CLASSES[role].owned.duplicate()
  game.clock+=1.01;tf.tick_sentries()
  var wanted: Array=tf.CLASSES[role].ammo.duplicate()
  if role=="engineer":wanted[3]=120
  var supplied:=true
  for i in 4:
   if wanted[i]>0 and s.ammo[i]<=0:supplied=false
   if wanted[i]==0 and s.ammo[i]!=0:supplied=false
  check(s.hp==30 and s.armor==7 and supplied and s.owned==tf.CLASSES[role].owned,role+" receives health, armour and all class ammo without new weapons")
 var ammo: Array=s.ammo.duplicate();game.clock+=.5;tf.tick_sentries();check(s.ammo==ammo,"Dispenser respects one-second supply interval")
 s.ammo=[0,0,0,0];s.team=1;game.clock+=1;tf.tick_sentries();check(s.ammo==[0,0,0,0],"Enemy cannot receive dispenser ammo")
 s.team=0;game.fighters[-1].position=point+Vector3(4,0,0);game.clock+=1;tf.tick_sentries();check(s.ammo==[0,0,0,0],"Supply requires teammate within three metres")
 print("DISPENSER_SUPPLY_RESULT ",JSON.stringify(failures));game.free();await process_frame;quit(0 if failures.is_empty() else 1)
