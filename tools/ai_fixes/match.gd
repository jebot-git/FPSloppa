extends SceneTree
var game
var traces:Array=[]
var options: Dictionary
var stats: Dictionary={}
var behaviour: Dictionary={"idle_examples":[],"active_samples":0,"idle_samples":0,"close_pair_samples":0,"team_pair_samples":0,"goal_changes":0,"target_changes":0,"yaw_degrees":0.0,"hill_occupied_samples":0,"hill_samples":0}
var previous_goal: Dictionary={}
var previous_enemy: Dictionary={}
var previous_yaw: Dictionary={}
func _initialize():run.call_deferred()
func run() -> void:
 options=JSON.parse_string(OS.get_cmdline_user_args()[0]);seed(int(options.get("seed",7129)))
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 if game.get_script()==null:push_error("Arena script failed to load");game.free();quit(1);return
 if options.has("map_entry"):
  game.map_catalog=game.map_catalog.filter(func(row):return row.id!=options.map)
  game.map_catalog.append(options.map_entry)
 game.selected_map=options.map;game.start_host("Bot soak observer",0,100,int(options.get("minutes",60)),true,options.mode,options.get("rules","doom"))
 game.set_physics_process(false)
 if not game.active or game.current_map!=options.map:push_error("SOAK_START_FAILED "+str(options));quit(1);return
 game.players[1].spectator=true;game._spawn(1);game.set_process(false);game.dedicated=true
 for id in [-4,-5,-6,-7,-8]:game._add_player(id,"Bot "+str(-id))
 var classes: Array=game.match_mode.fortress.CLASSES.keys()
 for id in game.players:
  if id>=0:continue
  game.players[id].team=(abs(id)%2+int(options.get("mirror",0)))%2 if game.match_mode.team_game() else -1
  if options.mode=="tf":game.players[id].tf_next=options.class_mix[int((abs(id)-1)/2)%options.class_mix.size()]
  game._spawn(id)
 game.frag_limit=100000;game.match_mode.capture_limit=100000;game.match_mode.hill_limit=100000
 var old=game.server_log;var metrics=preload("res://tools/ai_balance/recorder.gd").new();metrics.game=game;game.add_child(metrics);game.server_log=metrics;old.queue_free()
 var deadline:=Time.get_ticks_msec()+30000
 while not game.bots.ready_to_walk or not game.bots.navigation.ready():
  if Time.get_ticks_msec()>deadline:push_error("Navigation bake timed out");quit(1);return
  await physics_frame
 if options.has("ai_script"):
  game.bots.free();game.bots=load(options.ai_script).new();game.add_child(game.bots);game.bots.setup(game)
  while not game.bots.ready_to_walk or not game.bots.navigation.ready():
   if Time.get_ticks_msec()>deadline:push_error("Snapshot navigation bake timed out");quit(1);return
   await physics_frame
 game.bots.navigation.install_links()
 for i in 120:game.bots.navigation.update_jump_links();await physics_frame
 seed(int(options.seed));game.match_mode.reset()
 for id in game.players:game._spawn(id)
 game.bots.brains.clear();game.bots.teamplay.stats.clear();metrics.begin()
 var start: float=game.clock;var last_sample:=start;var before: Dictionary={};var serial: Dictionary={};var shots: Dictionary={};var still: Dictionary={};var window: Dictionary={}
 var by_bot: Dictionary={};var weapons: Dictionary={};var goals: Dictionary={};var samples: Array=[];var ticks: Array=[]
 for id in game.players:
  if id>=0:continue
  before[id]=game.fighters[id].position;window[id]=before[id];serial[id]=game.players[id].serial;shots[id]=game.players[id].shots;still[id]=0.0
  by_bot[id]={"distance":0.0,"stationary_seconds":0.0,"active_seconds":0.0,"max_stall":0.0,"shots":0,"weapon_switches":0,"last_weapon":game.players[id].weapon,"cells":{},"stalls":[]}
 var stage:=0;var checkpoint:=0;var score: Array=[0,0];var initial_bytes:=Performance.get_monitor(Performance.MEMORY_STATIC)
 var profile_tick: bool=options.get("profile_tick",false)
 if profile_tick:game.set_physics_process(false)
 while game.clock-start<float(options.get("seconds",300)) and not (options.mode=="as" and game.match_mode.assault.finished):
  await physics_frame
  if profile_tick:
   var began:=Time.get_ticks_usec()
   game._physics_process(1.0/60)
   if game.clock-start>30:ticks.append((Time.get_ticks_usec()-began)/1000.0)
  metrics.observe(1.0/60)
  if not game.active or not is_instance_valid(game.bots):push_error("Soak match stopped unexpectedly");quit(1);return
  stage=maxi(stage,game.match_mode.assault.stage);checkpoint=maxi(checkpoint,game.match_mode.assault.checkpoint)
  for team in 2:score[team]=maxi(score[team],game.match_mode.scores[team])
  for id in by_bot:
   var state: Dictionary=game.players[id];var point: Vector3=game.fighters[id].position;var row: Dictionary=by_bot[id]
   if state.serial==serial[id] and before[id].distance_to(point)<2:row.distance+=before[id].distance_to(point)
   else:window[id]=point;still[id]=0.0
   var fired: int=maxi(0,state.shots-shots[id]);row.shots+=fired
   if fired>0:weapons[str(state.weapon)]=int(weapons.get(str(state.weapon),0))+fired
   if state.weapon!=row.last_weapon:row.weapon_switches+=1;row.last_weapon=state.weapon
   before[id]=point;serial[id]=state.serial;shots[id]=state.shots
  if game.clock-last_sample>=1.0:
   var dt: float=game.clock-last_sample;last_sample=game.clock
   if not profile_tick:ticks.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
   for id in by_bot:
    var s: Dictionary=game.players[id];var b: Dictionary=game.bots.brains[id];var point: Vector3=game.fighters[id].position;var row: Dictionary=by_bot[id]
    if not s.dead and not game.match_mode.special.blocked(id) and game.intermission<=0:
     behaviour.active_samples+=1
     if b.goal_kind=="idle":
      behaviour.idle_samples+=1
      if behaviour.idle_examples.size()<12:behaviour.idle_examples.append({"id":id,"time":game.clock-start,"position":str(point),"nav":str(NavigationServer3D.map_get_closest_point(game.bots.region.get_navigation_map(),point)),"avoid":str(b.avoid)})
     if previous_goal.has(id) and previous_goal[id]!=b.goal_key:behaviour.goal_changes+=1
     if previous_enemy.has(id) and previous_enemy[id]!=b.enemy:behaviour.target_changes+=1
     if previous_yaw.has(id):behaviour.yaw_degrees+=absf(rad_to_deg(angle_difference(previous_yaw[id],s.yaw)))
     previous_goal[id]=b.goal_key;previous_enemy[id]=b.enemy;previous_yaw[id]=s.yaw
     for friend in by_bot:
      if friend<=id or not game.bots.alive(friend) or not game.match_mode.same_team(id,friend):continue
      behaviour.team_pair_samples+=1
      if point.distance_to(game.fighters[friend].position)<2:behaviour.close_pair_samples+=1
    goals[b.goal_kind]=int(goals.get(b.goal_kind,0))+1
    if not s.dead and not game.match_mode.special.blocked(id) and game.intermission<=0:
     row.active_seconds+=dt;row.cells[str(Vector3i(floor(point.x/4),floor(point.y/3),floor(point.z/4)))]=true
     var intentional: bool=b.hold and point.distance_to(b.goal)<game.bots.stop_radius(b)+.3
     if point.distance_to(window[id])<.4 and not intentional:
      row.stationary_seconds+=dt;still[id]+=dt;row.max_stall=maxf(row.max_stall,still[id])
      if still[id]>5 and row.stalls.size()<8:row.stalls.append({"time":game.clock-start,"position":str(point),"goal":b.goal_key,"path_size":b.path.size(),"step":b.step,"next_point":str(b.path[b.step]) if b.step<b.path.size() else "none","velocity":str(game.fighters[id].velocity),"in_water":game.fighters[id].in_water,"underwater":game.fighters[id].underwater,"move":str(s.move),"swim":str(s.swim),"jump":s.jump,"recover":str(b.recover_direction)})
     else:still[id]=0.0
    else:still[id]=0.0
    window[id]=point
   if samples.size()%5==0:
    var frame:Array=[]
    for peer in by_bot:
     var actor=game.fighters[peer];var state:Dictionary=game.players[peer];var brain:Dictionary=game.bots.brains[peer]
     frame.append({"id":peer,"position":actor.position,"velocity":actor.velocity,"platform_velocity":actor.get_platform_velocity(),"platform_mask":actor.platform_floor_layers,"floor":actor.is_on_floor(),"supported":actor.is_supported(),"collisions":actor.get_slide_collision_count(),"floor_normal":actor.get_floor_normal(),"contacts":contacts(actor),"dead":state.dead,"frozen":game.match_mode.special.frozen.has(peer),"goal":brain.goal,"kind":brain.goal_kind,"key":brain.goal_key,"step":brain.step,"path":brain.path,"enemy":brain.enemy,"owned":state.owned.duplicate(),"ammo":state.ammo.duplicate(),"in_water":actor.in_water,"underwater":actor.underwater,"nav":NavigationServer3D.map_get_closest_point(game.bots.region.get_navigation_map(),actor.position)})
    traces.append({"time":game.clock-start,"bots":frame})
   if samples.size()%30==0:print("BOT_SOAK_PROGRESS ",options.map," ",options.mode," ",options.get("rules","doom")," time=",round(game.clock-start)," shots=",weapons," scores=",score," stage=",stage," checkpoint=",checkpoint)
   if game.match_mode.kind=="koth":
    behaviour.hill_samples+=1
    if game.match_mode.hill_owner!=-1:behaviour.hill_occupied_samples+=1
   samples.append({"time":game.clock-start,"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"projectiles":game.projectiles.size()})
 ticks.sort()
 for row in by_bot.values():row.cells=row.cells.size();row.erase("last_weapon")
 var result: Dictionary={"traces":traces,"balance":metrics.finish(),"behaviour":behaviour,"actual_map":game.current_map,"effective_rules":game.armory.effective(),"case":options,"simulated_seconds":game.clock-start,"bots":by_bot,"weapons":weapons,"damage":metrics.damage,"events":metrics.events,"counts":metrics.totals,"goals":goals,"teamplay":game.bots.teamplay.stats,"score":score,"as_stage":stage,"as_checkpoint":checkpoint,"links":game.bots.navigation.links.size(),"jump_links":game.bots.navigation.jump_links,"physics_p50_ms":ticks[ticks.size()/2] if not ticks.is_empty() else 0,"physics_p95_ms":ticks[int(ticks.size()*.95)] if not ticks.is_empty() else 0,"memory_start":initial_bytes,"samples":samples}
 FileAccess.open(options.output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("BOT_SOAK_RESULT ",options.output)
 game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit()

func contacts(actor)->Array:
 var rows:Array=[]
 for i in actor.get_slide_collision_count():
  var c=actor.get_slide_collision(i);var body=c.get_collider()
  rows.append({"name":str(body.get_path()) if is_instance_valid(body) else "none","class":body.get_class() if is_instance_valid(body) else "none","position":body.global_position if body is Node3D else Vector3.ZERO,"layer":body.collision_layer if body is CollisionObject3D else -1,"normal":c.get_normal(),"velocity":c.get_collider_velocity()})
 return rows
