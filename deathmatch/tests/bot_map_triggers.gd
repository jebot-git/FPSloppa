extends SceneTree
var game
var failures: Array=[]
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run() -> void:
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 for map in ["qsrc_dm6","qsrc_dm2"]:
  game.selected_map=map;game.start_host("Bot trigger tests",0,100,60,true,"dm","quake")
  game.set_physics_process(false);game.set_process(false)
  for id in [1,-2,-3]:game._peer_left(id)
  var ai=game.bots;var logic=ai.map_triggers.logic
  var deadline=Time.get_ticks_msec()+20000
  while not ai.navigation.ready():
   if Time.get_ticks_msec()>deadline:check(false,"Navigation ready");finish();return
   await physics_frame
  for node in logic.rows:
   var row: Dictionary=logic.rows[node]
   if map=="qsrc_dm6" and row.kind=="func_door_secret":
    var actor=game.fighters[-1];var center: Vector3=row.bounds.get_center();var found:=false
    for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
     var p: Vector3=center+direction*(logic.extent(row.bounds.size,direction)*.5+2)
     var floor_hit: Dictionary=ai.navigation.ray(p+Vector3.UP,p-Vector3.UP*4)
     if floor_hit.is_empty() or floor_hit.normal.y<.7:continue
     actor.position=floor_hit.position+Vector3.UP*.05;actor.velocity=Vector3.ZERO
     await physics_frame
     if game._trace(ai.eye(-1),center,-1).get("map_node")==node:found=true;break
    check(found,"DM6 secret has a reachable shooting approach")
    game.players[-1].invulnerable=game.clock+30
    var initial_shots: int=game.players[-1].shots
    var brain: Dictionary=ai.new_brain(-1);brain.goal=actor.position;brain.goal_kind="roam";brain.plan_at=INF;brain.next=INF;ai.brains[-1]=brain
    for frame in 480:
     await physics_frame;game._physics_process(1.0/60);brain.next=INF
     if game.gates[row.gate].open:break
    check(game.gates[row.gate].open and game.players[-1].shots>initial_shots,"DM6 bot discovers and shoots secret using actual weapon input")
    check(not ai.map_triggers.available(node),"Bot stops firing at an open secret")
   if map=="qsrc_dm2" and row.kind=="func_door" and not row.data.get("targetname","").is_empty():
    var controls: Array=ai.map_triggers.controls(node)
    check(not controls.is_empty(),"DM2 bot resolves upstream controls for "+str(row.data.targetname))
  if map=="qsrc_dm2":
   var pressed:=false
   for node in logic.rows:
    var row: Dictionary=logic.rows[node]
    if row.kind!="func_button" or row.hp>0:continue
    var actor=game.fighters[-1];var center: Vector3=row.bounds.get_center()
    for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
     var p: Vector3=center+direction*(logic.extent(row.bounds.size,direction)*.5+1.3)
     var floor_hit: Dictionary=ai.navigation.ray(p+Vector3.UP,p-Vector3.UP*3)
     if floor_hit.is_empty() or floor_hit.normal.y<.7:continue
     actor.position=floor_hit.position+Vector3.UP*.04;actor.velocity=Vector3.ZERO
     await physics_frame
     var hit: Dictionary=game._trace(ai.eye(-1),center,-1)
     if hit.get("map_node")!=node:continue
     var action: Dictionary=ai.map_triggers.approach(node,-1)
     if action.is_empty():continue
     action.node=node;action.until=game.clock+8
     var brain: Dictionary=ai.new_brain(-1);brain.map_action=action;brain.map_avoid={};brain.goal=action.goal;brain.path=action.path;brain.goal_key="map_control";brain.goal_kind="map_control";brain.hold=true;brain.plan_at=INF;brain.next=INF;ai.brains[-1]=brain
     for frame in 480:
      await physics_frame;game._physics_process(1.0/60);brain.next=INF
      if game.gates[row.gate].open:pressed=true;break
     if pressed:break
    if pressed:break
   check(pressed,"DM2 bot walks into a contact button using normal movement")
  if map=="qsrc_dm2":
   var tested:=false
   for node in logic.rows:
    var row: Dictionary=logic.rows[node]
    if row.kind!="func_door" or float(row.data.get("dmg",0))<=0:continue
    game.fighters[-1].position=row.bounds.get_center()-Vector3.UP*game.fighters[-1].torso_height()
    for control in ai.map_triggers.controls(node):
     check(ai.map_triggers.friendly_trap(control,-1),"Bot refuses a crusher switch while inside its swept volume");tested=true
   check(tested,"Real DM2 crusher safety exercised")
  game.disconnect_game();await process_frame
 finish()
func finish() -> void:
 FileAccess.open("res://test-results/release014/bot-map-triggers.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"passed":failures.is_empty()},"  "))
 game.queue_free();await process_frame;print("BOT_MAP_TRIGGERS_RESULT ",failures);quit(0 if failures.is_empty() else 1)
