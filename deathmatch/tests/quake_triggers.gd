extends SceneTree
var game
var failures: Array=[]
var report: Array=[]
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run() -> void:
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.start_host("Map tests",0,100,10,false,"dm","quake");game.set_physics_process(false);game.set_process(false)
 for map in ["qsrc_dm1","qsrc_dm2","qsrc_dm3","qsrc_dm4","qsrc_dm5","qsrc_dm6","qsrc_dm7"]:
  check(game._rotate_map(map),map+" loads")
  var runtime=game.get_node("Map/MapRuntime");runtime.set_physics_process(false)
  var logic=runtime.triggers
  await physics_frame;await physics_frame
  var buttons:=0;var shot:=0;var secrets:=0;var trains:=0;var touch:=0
  for node in logic.rows:
   var row: Dictionary=logic.rows[node]
   if row.kind=="func_train":
    trains+=1;check(row.has("route"),map+" train has complete corner route")
    var before: Vector3=node.position;game.clock+=1;logic.tick_trains()
    check(node.position.distance_to(before)>.01,map+" train moves")
   if row.kind=="func_door" and int(row.data.get("spawnflags",0))&1:
    var gate: Dictionary=game.gates[row.gate]
    check(gate.travel.dot(logic.direction(row.data))<0,map+" start-open door reverses its travel")
   if row.kind not in ["func_button","func_door_secret","trigger_multiple"]:continue
   for other in logic.rows:
    logic.rows[other].until=0
   for gate in game.gates:
    if gate.has("motion_tween") and is_instance_valid(gate.motion_tween):gate.motion_tween.kill()
    gate.open=false;gate.node.position=gate.base_position if gate.has("base_position") else gate.node.position
   logic.pending.clear()
   game.fighters[1].position=Vector3(1000,100,1000)
   if row.kind=="func_button":buttons+=1
   if row.kind=="func_door_secret":secrets+=1
   if row.hp>0:
    shot+=1
    var hit: Dictionary={}
    for axis in [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]:
     var center: Vector3=row.bounds.get_center()
     var start: Vector3=center+axis*(logic.extent(row.bounds.size,axis)*.5+.08)
     hit=game._trace(start,center,1)
     if hit.get("map_node")==node:break
    check(hit.get("map_node")==node,map+" damage trace reaches "+row.kind)
    game._damage_map_hit(hit,1,1)
   elif row.kind=="func_button":
    game.fighters[1].position=row.bounds.get_center()-Vector3.UP*.8
    logic.tick()
    check(game.gates[row.gate].open,map+" body contact presses button")
    touch+=1
   else:
    check(logic.activate(node,1),map+" touch trigger activates")
   game.fighters[1].position=Vector3(1000,100,1000)
   game.clock+=2;logic.tick()
   if row.gate>=0:check(game.gates[row.gate].open,map+" mover activated")
   var target: String=row.data.get("target","")
   if not target.is_empty():
    check(logic.targets.has(target),map+" target "+target+" resolves")
    for destination in logic.targets.get(target,[]):
     var index: int=logic.rows[destination].gate
     if index>=0:check(game.gates[index].open,map+" target "+target+" opens every panel")
  if map=="qsrc_dm2":
   for node in logic.rows:
    var row: Dictionary=logic.rows[node]
    if row.kind!="func_door" or int(row.data.get("dmg",0))!=1000:continue
    var gate: Dictionary=game.gates[row.gate]
    row.until=0;gate.open=false;node.position=gate.base_position
    game.players[1].dead=false;game.players[1].hp=100;game.players[1].invulnerable=0
    game.fighters[1].position=row.bounds.get_center()-Vector3.UP*.8
    logic.activate(node,1);logic.crush()
    check(game.players[1].dead,"DM2 moving crusher applies authored lethal damage")
    game._spawn(1);break
  report.append({"map":map,"buttons":buttons,"shot_activators":shot,"secret_doors":secrets,"trains":trains,"contact_buttons":touch})
 await chain_tests()
 game.disconnect_game();game.free();await process_frame
 FileAccess.open("res://test-results/quake-trigger-results.json",FileAccess.WRITE).store_string(JSON.stringify({"maps":report,"failures":failures},"  "))
 print("QUAKE_TRIGGERS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)

func chain_tests() -> void:
 var runtime=game.get_node("Map/MapRuntime")
 var logic=preload("res://deathmatch/maps/triggers.gd").new()
 var nodes: Array=[]
 for data in [
  {"classname":"trigger_relay","targetname":"relay","target":"counter"},
  {"classname":"trigger_counter","targetname":"counter","count":"2","target":"end","delay":"1"},
  {"classname":"trigger_once","targetname":"end"},
  {"classname":"trigger_relay","targetname":"cycle1","target":"cycle2"},
  {"classname":"trigger_relay","targetname":"cycle2","target":"cycle1"},
  {"classname":"trigger_relay","targetname":"kill","killtarget":"victim","delay":".5"},
  {"classname":"info_null","targetname":"victim"}
 ]:
  var node:=Node3D.new();node.set_script(preload("res://deathmatch/maps/entity.gd"));node.attributes=data
  game.get_node("Map").add_child(node);nodes.append(node)
 logic.setup(runtime,nodes)
 check(logic.use_target("relay",1) and logic.rows[nodes[1]].count==1 and logic.rows[nodes[2]].until==0,"Counter waits for two independent relay activations")
 logic.use_target("relay",1)
 check(logic.rows[nodes[2]].until==0,"Counter respects authored delay")
 game.clock+=1.1;logic.tick()
 check(is_inf(logic.rows[nodes[2]].until),"Delayed counter activates one-shot target")
 check(not logic.activate(nodes[2],1),"One-shot trigger cannot activate twice")
 check(logic.use_target("cycle1",1) and logic.pending.is_empty(),"Cyclic relay chain is bounded")
 logic.use_target("kill",1)
 check(nodes[6].visible,"Delayed killtarget remains visible until due")
 game.clock+=.6;logic.tick()
 check(not nodes[6].visible and logic.killed_targets==["victim"],"Delayed killtarget disables target and records replicated state")
 for node in nodes:node.free()
