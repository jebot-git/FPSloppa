extends SceneTree
var g
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);print("FAIL ",label)
func run():
 var key: String=OS.get_cmdline_user_args()[0]
 g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map=key
 g.start_host("Varq DE acceptance",0,20,10,true,"de","cs16",15)
 g.set_process(false);g.set_physics_process(false)
 check(g.current_map==key,"Requested converted map loaded")
 check(key in g.maps_for_mode("de"),"Converted map offered in DE")
 check(g.armory.effective()=="cs16","CS arsenal selected")
 for id in g.players.keys():
  if id<0:g._peer_left(id)
 g._add_player(-1,"Defender");g.players[1].team=0;g.players[-1].team=1
 for id in [1,-1]:g.players[id].input_blocked=false;g.players[id].spectator=false
 await physics_frame;await physics_frame
 var de=g.match_mode.defusal
 for site in 2:
  g.intermission=0;g.match_mode.reset();g.clock+=100
  for id in [1,-1]:g._spawn(id)
  de.tick(0)
  check(de.phase=="prepare","Site %d preparation"%site)
  check(de.buy(1,10),"Site %d legal purchase"%site)
  g.clock=de.phase_end;de.tick(0)
  g.fighters[1].position=de.sites[site];g.fighters[1].velocity=Vector3.ZERO;de.carrier=1;de.held=true
  for i in 4:g.clock+=.2;de.digit(1,de.arm_code[de.arm_index])
  check(de.arm_index==4,"Site %d bomb armed"%site)
  # Planting is directional; find a valid facing while standing at the goal.
  for facing in 16:
   g.players[1].yaw=facing*TAU/16;g.players[1].pitch=0.
   var candidate: Dictionary=de.placement(1)
   if not candidate.is_empty() and candidate.site==site:break
  check(de.plant(1,site) and de.planted,"Site %d authoritative plant"%site)
  if de.planted:
   g.fighters[-1].position=de.bomb_position;g.fighters[-1].velocity=Vector3.ZERO;de.account(-1).tool=false
   for i in 8:g.clock+=.2;de.digit(-1,de.defuse_code[de.defuse_index])
   check(de.phase=="post" and de.message=="BOMB DEFUSED","Site %d authoritative defusal"%site)
 var report:={"id":key,"checks":checks,"failures":failures}
 var folder:="res://test-results/varq-de/"+key;DirAccess.make_dir_recursive_absolute(folder)
 FileAccess.open(folder+"/acceptance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("VARQ_ACCEPTANCE ",JSON.stringify(report));g.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
