extends SceneTree
const Classes=["scout","soldier","demoman","medic","heavy","engineer"]
var g
var options: Dictionary
var metrics
var samples: Array=[]
var placements: Array=[]
var origin:=0.
var pilot_seconds:=0.
var moving_seconds:=0.
var blocked_seconds:=0.
var pilot_changes: Array=[]
var previous_pilot:=0
var camera: Camera3D
var label: Label
var running:=false
var capture_at:=0.
func _initialize():run.call_deferred()
func run() -> void:
 options=JSON.parse_string(OS.get_cmdline_user_args()[0]);seed(int(options.get("seed",7129)))
 var profile: String=options.get("profile","tf")
 if profile!="tf":push_error("TITANBALL supports TF classes and Quake loadouts only");quit(1);return
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 g=load("res://deathmatch/arena.tscn").instantiate()
 if profile!="tf":
  g.match_mode.fortress.free();g.match_mode.fortress=preload("res://tools/titanball/simulation/classless.gd").new()
  g.armory=preload("res://tools/titanball/simulation/rules.gd").new()
 if options.get("pilot_health","fixed200")=="class":
  g.match_mode.fortress.walkers.free();g.match_mode.fortress.walkers=preload("res://tools/titanball/simulation/class_health_baseline.gd").new()
  g.match_mode.fortress.walkers.name="Walkers";g.match_mode.fortress.add_child(g.match_mode.fortress.walkers)
 root.add_child(g);g.selected_map="tb_ashfall"
 g.start_host("TITANBALL 6v6 balance observer",0,100,10,true,"tb","quake" if profile=="tf" else profile)
 g.match_mode.fortress.walkers.heavy_ordnance_only=options.get("pilot_damage","heavy")=="heavy"
 g.match_mode.fortress.walkers.pilot_regeneration=options.get("pilot_healing","off")=="station"
 g.set_physics_process(false);g.set_process(false)
 if not g.active or g.current_map!="tb_ashfall":push_error("Wrong map or inactive arena");quit(1);return
 g.players[1].spectator=true;g._spawn(1)
 for id in range(-4,-13,-1):g._add_player(id,"Bot %02d"%-id)
 for id in g.players:
  if id>=0:continue
  g.players[id].team=(-id-1)%2
  g.players[id].tf_next=Classes[(-id-1)/2] if profile=="tf" else "none"
  g._spawn(id)
 var nav_deadline:=Time.get_ticks_msec()+30000
 while not g.bots.ready_to_walk or not g.bots.navigation.ready():
  if Time.get_ticks_msec()>nav_deadline:push_error("Navigation unavailable");quit(1);return
  await physics_frame;OS.delay_msec(1)
 g.bots.navigation.install_links()
 seed(int(options.get("seed",7129)));g.match_mode.reset()
 for id in g.players:g._spawn(id)
 g.bots.brains.clear()
 if profile!="tf":place_pickups()
 var old=g.server_log;metrics=preload("res://tools/titanball/simulation/recorder.gd").new();metrics.game=g;g.add_child(metrics);g.server_log=metrics;old.queue_free();metrics.begin()
 if not g.headless:
  for layer in g.find_children("*","CanvasLayer",true,false):layer.hide()
  g._process(0.)
  if is_instance_valid(g.viewmodel):g.viewmodel.hide()
  camera=Camera3D.new();camera.cull_mask=g.camera.cull_mask;camera.fov=85;g.add_child(camera);camera.make_current()
  camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
  var layer:=CanvasLayer.new();root.add_child(layer);label=Label.new();layer.add_child(label);label.position=Vector2(20,20);label.add_theme_font_size_override("font_size",24)
  label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2)
 Engine.physics_ticks_per_second=60*int(options.get("speed",1));Engine.time_scale=float(options.get("speed",1));Engine.max_physics_steps_per_frame=32
 origin=g.clock;running=true;var next_sample:=0.
 print("TB_SIM_START ",profile," rules=",g.armory.effective()," classes=",g.match_mode.fortress.enabled()," pickups=",placements.size())
 while g.clock-origin<float(options.get("seconds",1030)) and g.match_mode.titanball.winner==-1:
  await physics_frame
  g._physics_process(1./60.)
  var r: Dictionary=g.match_mode.fortress.walkers.robots.values()[0]
  var active: bool=not g.match_mode.titanball.preparing()
  if active and r.pilot!=0:pilot_seconds+=1./60.
  if active and r.speed>.001:moving_seconds+=1./60.
  if active and r.pilot!=0 and r.speed<.001:blocked_seconds+=1./60.
  if r.pilot!=previous_pilot:pilot_changes.append({"time":g.clock-origin,"from":previous_pilot,"to":r.pilot,"distance":r.distance});previous_pilot=r.pilot
  if g.clock-origin>=next_sample:
   next_sample+=1.;sample()
  if not g.headless:g._process(1./60.);draw_view(r)
  if not g.headless and g.clock-origin>=capture_at:
   capture_at+=60.;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(options.output.get_basename()+"-%04d.png"%int(g.clock-origin))
 running=false
 var result: Dictionary={"options":options,"profile":profile,"effective_rules":g.armory.effective(),"classes":g.match_mode.fortress.enabled(),"map":g.current_map,"stations":g.match_mode.titanball.stations,"vantages":g.match_mode.titanball.vantages,"map_sha256":FileAccess.get_sha256("res://maps/tb_ashfall.bsp"),"seconds":g.clock-origin,"winner":g.match_mode.titanball.winner,"progress":g.match_mode.titanball.progress,"checkpoints":g.match_mode.titanball.cleared,"pilot_seconds":pilot_seconds,"moving_seconds":moving_seconds,"manned_stopped_seconds":blocked_seconds,"pilot_changes":pilot_changes,"samples":samples,"deaths":metrics.deaths,"damage":metrics.damage,"pickups":metrics.pickups,"placements":placements,"damage_events":metrics.damage_events,"cannon_volleys":metrics.cannon_volleys,"boardings":metrics.boardings,"deployable_crushes":metrics.deployable_crushes,"events":metrics.events,"teamplay":g.bots.teamplay.stats}
 result["pilot_healing"]=metrics.pilot_healing
 result["blocked_hull_hits"]=metrics.blocked_hull_hits
 FileAccess.open(options.output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("TB_SIM_RESULT ",options.output," progress=",result.progress," winner=",result.winner)
 g.disconnect_game();g.queue_free();await process_frame;await process_frame;quit()
func sample() -> void:
 var rows: Array=[]
 for id in g.players:
  if id>=0:continue
  var s: Dictionary=g.players[id];var b: Dictionary=g.bots.brains.get(id,{})
  rows.append({"id":id,"team":s.team,"class":s.tf_class,"hp":s.hp,"dead":s.dead,"kills":s.kills,"deaths":s.deaths,"shots":s.shots,"owned":s.owned.duplicate(),"weapon":s.weapon,"position":g.fighters[id].position,"vantage":vantage_at(g.fighters[id].position),"goal":b.get("goal_key",""),"goal_position":b.get("goal",Vector3.ZERO),"path":b.get("path",[]).size(),"enemy":b.get("enemy",0)})
 var tb=g.match_mode.titanball;var r: Dictionary=g.match_mode.fortress.walkers.robots.values()[0]
 samples.append({"time":g.clock-origin,"left":g.round_left,"preparation":tb.preparation_left,"distance":r.distance,"speed":r.speed,"body_yaw":r.get("body_yaw",0.),"robot_state":r.state,"ladder_deployed":g.match_mode.fortress.walkers.ladder_visible(r),"exit_lock":r.get("exit_lock",0.),"pilot":r.pilot,"checkpoint":tb.cleared,"bots":rows})
 if samples.size()%30==1:print("TB_SIM_PROGRESS ",options.profile," t=",roundi(g.clock-origin)," distance=",snappedf(r.distance,.1)," pilot=",r.pilot," deaths=",metrics.deaths.size()," pickups=",metrics.pickups.size()," goals=",rows.map(func(b):return b.goal))
func vantage_at(position: Vector3) -> int:
 for i in g.match_mode.titanball.vantages.size():
  var point: Vector3=g.match_mode.titanball.vantages[i].position
  if position.distance_to(point)<3.0 and absf(position.y-point.y)<.7:return i
 return -1
func draw_view(r: Dictionary) -> void:
 var w=g.match_mode.fortress.walkers
 var pose: Transform3D=w.transform(r)
 var focus: Vector3=r.position+Vector3.UP*4
 var wanted: Vector3=pose*Vector3(12,10,-16)
 var query:=PhysicsRayQueryParameters3D.create(focus,wanted,1)
 query.exclude=[w.bodies[r.id].get_rid()]
 var wall: Dictionary=g.get_world_3d().direct_space_state.intersect_ray(query)
 if g.clock-origin<.02:print("TB_OBSERVER_CAMERA ",JSON.stringify({"focus":focus,"wanted":wanted,"hit":wall}))
 camera.position=wanted if wall.is_empty() else wall.position+(focus-wall.position).normalized()*.6
 camera.look_at(focus);camera.make_current()
 label.text="TITANBALL · 6v6 · %s · %sx speed · %s\n%s\nTime %.0fs · %.1f / 300 m · Pilot %s · Deaths %s"%[options.profile.to_upper(),options.get("speed",1),options.get("revision","test"),"PREPARATION" if g.match_mode.titanball.preparing() else "RED ATTACKS / BLUE DEFENDS",g.round_left,r.distance,r.pilot,metrics.deaths.size()]
 var high: Array=[0,0]
 if not samples.is_empty():
  for b in samples.back().bots:
   if not b.dead and b.vantage>=0:high[b.team]+=1
 label.text+="\nHigh ground: RED %d / BLUE %d · Resupply stations: %d"%[high[0],high[1],g.match_mode.titanball.stations.size()]
func place_pickups() -> void:
 var rng:=RandomNumberGenerator.new();rng.seed=int(options.get("seed",7129))+901
 var w=g.match_mode.fortress.walkers;var r: Dictionary=w.robots.values()[0]
 # Equal cache counts in each route third; cover-side spots and a cache at each end.
 var tb=g.match_mode.titanball
 var spawn_groups: Array=tb.attacker_spawns.duplicate();spawn_groups.append(tb.defender_spawns)
 for group in spawn_groups:
  for point in group:
   add_pickup("weapon",3 if options.profile=="ut99" else 5,point,0.,true)
 var probes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/Ashfall/probes.json"))
 var slots: Array=[3,4,5,6,7,9,1,10] if options.profile=="ut99" else [3,4,5,6,7,3,4,5]
 for zone in 3:
  var shuffled:=slots.duplicate()
  for i in range(shuffled.size()-1,0,-1):var j:=rng.randi_range(0,i);var swap=shuffled[i];shuffled[i]=shuffled[j];shuffled[j]=swap
  for i in 8:
   var distance: float=clampf(zone*100+8+i*11+rng.randf_range(-3,3),5,295)
   var pose: Transform3D=w.Route.sample(r.path,distance)
   var wanted: Vector3=pose*Vector3((1 if i%2==0 else -1)*rng.randf_range(7,12),0,0)
   if i%4==2:
    var nearest:=INF;var street_point:=wanted
    for room in probes.rooms:
     var raw: Array=room.centre;var spot:=Vector3(raw[0],raw[1],raw[2]);var separation:=spot.distance_to(street_point)
     if separation<nearest:nearest=separation;wanted=spot if separation<28 else wanted
   var point:=NavigationServer3D.map_get_closest_point(g.bots.region.get_navigation_map(),wanted)
   if point.distance_to(wanted)>3:point=NavigationServer3D.map_get_closest_point(g.bots.region.get_navigation_map(),pose*Vector3(6 if i%2==0 else -6,0,0))
   var slot: int=shuffled[i]
   if options.profile=="ut99" and slot==9 and zone!=1:slot=5
   add_pickup("weapon",slot,point,distance)
   var ammo: int=g.armory.data(slot).ammo
   if ammo>=0:add_pickup("ammo",ammo,NavigationServer3D.map_get_closest_point(g.bots.region.get_navigation_map(),point+pose.basis.z*2),distance)
func add_pickup(kind: String,item: int,point: Vector3,distance: float,basic: bool=false) -> void:
 var p: Dictionary={"kind":kind,"item":item,"position":point+Vector3.UP*.05,"available":true,"respawn":0.,"node":null}
 if basic:p.weapon_stay=true;p.amount=40
 else:p.available=false;p.respawn=g.clock+60.
 if not g.headless:p.node=g._pickup_art(p)
 var path: PackedVector3Array=g.bots.navigation.path(g.spawn_points[0],point)
 assert(not path.is_empty(),"Unreachable test pickup: "+str(point))
 g.pickups.append(p);placements.append({"kind":kind,"item":item,"title":g.armory.data(item).name if kind=="weapon" else g.armory.ammo_names()[item],"position":p.position,"route_distance":distance,"basic":basic,"weapon_stay":basic,"release_seconds":0 if basic else 60})
