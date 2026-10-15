extends Node
## Default dedicated CQ host. Godot owns admission/assets/transport/Jolt; C++ owns gameplay.
const Runtime=preload("res://deathmatch/native/runtime.gd")
const Codec=preload("res://deathmatch/native/authority_protocol.gd")
const Metadata=preload("res://deathmatch/native/cq_metadata.gd")
const Presentation=preload("res://deathmatch/native/cq_presentation.gd")
var game
var core
var enabled:=false
var server_enabled:=false
var origin:=0.
var epoch:=-1
var lives:Dictionary={}
var native_peers:Dictionary={}
var request_sequence:=0
var request_sequences:Dictionary={}
var action_sequences:Dictionary={}
var avatar_hashes:Dictionary={}
var default_reach:Dictionary={}
var last_tick:=-1
var received_tick:=-1
var assembly_tick:=-1
var pieces:Array[PackedByteArray]=[]
var received_parts:=0
var packed_size:=0
var raw_size:=0
var assembly_origin:=0.
var last_event:=0
var last_round:=-1
var death_effects:Dictionary={}
var metrics:Dictionary={}
var client_frame:Dictionary={}
var deployment_offered:=false
var deployed_peers:Dictionary={}
var adaptive_tick:=true
var fixed_tick_hz:=60
var previous_tick_us:=0
var observed_hz:=60
func _process(_delta:float)->void:
 if not serving() or not core or not adaptive_tick:return
 if not core.apply_adaptive_tick():push_error("Adaptive CQ rate change rejected");game.get_tree().quit(2);return
 var hz:int=Engine.physics_ticks_per_second
 if hz!=observed_hz:
  print("CQ_TICK_TRANSITION ",JSON.stringify({"from":observed_hz,"to":hz,"metrics":core.metrics()}));observed_hz=hz
func setup(arena)->void:game=arena
func configure_server(settings:Dictionary,args:PackedStringArray)->void:
 server_enabled=not args.has("--cq-script-authority")
 enabled=server_enabled
 adaptive_tick=settings.sv_cq_adaptive_tick==1 and not args.has("--cq-fixed-tick")
 fixed_tick_hz=int(settings.sv_cq_tick_rate)
func serving()->bool:return enabled and game.dedicated and game.multiplayer.is_server()
func initialise()->bool:
 if core:return true
 if not Runtime.available("FPSAuthority"):push_error("Resident CQ requires FPSAuthority");return false
 if game.lobby.enabled:push_error("Resident CQ uses the unified map; configure sv_lobby 0");return false
 if not game.dedicated:push_error("Resident CQ requires dedicated mode");return false
 Engine.physics_ticks_per_second=60 if adaptive_tick else fixed_tick_hz
 default_reach=preload("res://deathmatch/avatars/ut_format.gd").read("res://deathmatch/avatars/models/base/soldier.utavatar").manifest.ik_profile
 core=ClassDB.instantiate("FPSAuthority");origin=game.clock;epoch=game.map_epoch
 if adaptive_tick:
  if not core.configure_adaptive_tick():return false
 elif not core.configure_tick_rate(fixed_tick_hz):return false
 observed_hz=Engine.physics_ticks_per_second;previous_tick_us=0
 if not core.configure_world(game) or not core.configure_cq({"squads":true,"day_cycle":true,"cycle_offset":game.battle_map.lighting.cycle_time() if game.battle_map and game.battle_map.lighting else 0.,"round_seconds":game.time_limit if game.time_limit_enabled() else 0.}):return false
 if not core.configure_terrain(Metadata.terrain()):return false
 for team in 2:
  for point in game.match_mode.spawns(team):
   if not core.configure_spawn(team,point):return false
 for site in game.match_mode.objectives.sites:
  if not core.configure_zone(site.position,3.):return false
 var lamps:=PackedVector3Array()
 if game.battle_map and game.battle_map.lighting:
  for row in game.battle_map.lighting.metadata.get("lamps",[]):lamps.append(Vector3(row.position[0],row.position[1],row.position[2]))
 if not core.configure_lamps(lamps):return false
 for key in game.battery_tanks.rows:
  var row:Dictionary=game.battery_tanks.rows[key];var body:CharacterBody3D=game.battery_tanks.body(key);var offset:float=game.battery_tanks.profile(row).size.y*.5+.02
  for child in body.get_children():
   if child is CollisionShape3D:child.position.y+=offset
  body.position=row.position
  if core.attach_vehicle(["rocket","light","heavy","transport"].find(row.kind),body,float(row.yaw),int(row.team))<0:return false
 for id in game.players:
  if not game.players[id].spectator and not attach(id):return false
 print("CQ_RESIDENT_READY ",JSON.stringify({"map_epoch":epoch,"players":lives.size(),"physics_hz":Engine.physics_ticks_per_second,"adaptive_tick":adaptive_tick}))
 return true
func attach(id:int)->bool:
 if not core or lives.has(id) or not game.fighters.has(id):return lives.has(id)
 var actor=game.fighters[id];var state:Dictionary=game.players[id]
 if state.spectator:return true
 var life:int=core.attach_actor(id,actor,actor.body_shape,state.team,1<<2,PackedInt32Array([100,100,100,100]))
 if life<=0:return false
 lives[id]=life;state.serial=life
 var saved:Dictionary=game.classes.ensure(id);var profile:Dictionary={"role":Presentation.ROLES.find(saved.get("class","shocktroop")),"next":Presentation.ROLES.find(saved.get("next","shocktroop")),"xp":[],"primary":0,"secondary":0,"utility":0}
 for role in 4:
  var label:String=Presentation.ROLES[role];profile.xp.append(saved.get("xp",{}).get(label,0))
  if saved.get("primary_choices",{}).get(label,-1)==Presentation.ADVANCED[role]:profile.primary|=1<<role
  if saved.get("secondary_choices",{}).get(label,-1)==0:profile.secondary|=1<<role
  if saved.get("utility_choices",{}).get(label,"")==Presentation.UTILITY[role][1]:profile.utility|=1<<role
 profile.cooldowns=[]
 for key in ["dispenser_ready","cloak_ready","drone_ready","airstrike_ready","turret_ready"]:profile.cooldowns.append(maxf(0,float(saved.get(key,0.))-game.clock))
 if not core.configure_player(id,life,profile):return false
 if OS.get_cmdline_user_args().has("--stress-test") and not core.configure_stress(id,true):return false
 if id>0 and not deployed_peers.has(id) and core.has_method("stage_player"):core.stage_player(id)
 configure_avatar(id)
 return true
func configure_avatar(id:int)->void:
 if not core or not lives.has(id):return
 var hash:String=game.avatars.choices.get(id,{}).get("hash","")
 if avatar_hashes.get(id,"?")==hash:return
 var entry:Dictionary=game.avatars.library.entries.get(hash,{})
 var reach:Dictionary=entry.get("reach_profile",{})
 if reach.is_empty():
  reach=default_reach
 if core.configure_reach(id,reach):avatar_hashes[id]=hash
func detach(id:int)->void:
 if core and lives.has(id):
  save_profile(id)
  var state:Dictionary=core.inspect(id)
  if not state.is_empty():core.detach_actor(id,state.life)
 deployed_peers.erase(id);lives.erase(id);action_sequences.erase(id);avatar_hashes.erase(id);native_peers.erase(id);request_sequences.erase(id)
func input(id:int,c:Dictionary)->void:
 if not core or not lives.has(id) or c.get("map_epoch",epoch)!=epoch:return
 if not game._valid_input_reference(c):return
 if not c.get("input_life") is int or c.input_life<1 or c.input_life>4294967295 or c.seq<0 or c.seq>2147483647 or c.weapon<0 or c.weapon>11:return
 for key in ["jump","reload","crouch","prone","input_blocked","vr_device","reload_grip","reload_trigger","offhand_fire","jetpack","cq_drag","melee"]:
  if c.has(key) and not c[key] is bool:return
 var pose:Variant=c.get("xr",{})
 if not pose is Dictionary or (not pose.is_empty() and not core.validate_pose(pose)):return
 if not c.get("room",Vector3.ZERO) is Vector3 or not c.get("room",Vector3.ZERO).is_finite():return
 if c.has("view_time") and (not (c.view_time is float or c.view_time is int) or not is_finite(float(c.view_time))):return
 var safe:Dictionary={"life":c.get("input_life",-1),"seq":c.seq,"move":c.move,"yaw":c.yaw,"pitch":c.pitch,"weapon":c.weapon,"fire":c.fire,"jump":c.get("jump",false),"reload":c.get("reload",false),"slow":c.slow,"crouch":c.get("crouch",false),"prone":c.get("prone",false),"blocked":c.get("input_blocked",false),"xr":c.get("xr",{}),"vr_device":c.get("vr_device",false),"room":c.get("room",Vector3.ZERO),"reload_grip":c.get("reload_grip",false),"reload_trigger":c.get("reload_trigger",false),"offhand_fire":c.get("offhand_fire",false),"jetpack":c.get("jetpack",false),"cq_drag":c.get("cq_drag",false),"melee":c.get("melee",false),"respawn":c.get("respawn",false),"view_time":float(c.get("view_time",-1.))-origin if c.get("view_time",-1.)>=0 else -1.}
 for key in ["jump_event","jump_seq","jetpack_event"]:
  if c.get(key) is int and c[key]>=(-1 if key=="jump_seq" else 0) and c[key]<=2147483647:safe[key]=c[key]
 var edge:Variant=c.get("fire_event",[])
 if edge is Array and edge.size()==3 and edge.all(func(v):return v is int) and edge[0]>=0 and edge[0]<=2147483647 and edge[1]==safe.weapon and edge[2]>=1 and edge[2]<=7:safe.fire_event=edge
 if c.get("weapon_held") is bool:safe.weapon_held=c.weapon_held
 core.submit_packet(id,Codec.encode_input(safe))
func action(id:int,kind:int,a:int=0,b:int=0,c:int=0)->bool:
 if not core or not lives.has(id):return false
 var state:Dictionary=core.inspect(id)
 if state.is_empty():return false
 var seq:int=action_sequences.get(id,-1)+1;action_sequences[id]=seq
 return core.request_action(id,state.life,seq,kind,a,b,c)
func physics(delta:float)->void:
 var callback_start:=Time.get_ticks_usec()
 game.clock+=delta
 if not game.active:return
 game.multiplayer.poll()
 if not initialise():game.get_tree().quit(2);return
 if game.map_epoch!=epoch:
  reset_instance()
  if not initialise():game.get_tree().quit(2);return
 # Initialisation can change the engine rate. Wait for a matching engine step.
 if not is_equal_approx(delta,1.0/Engine.physics_ticks_per_second):return
 if game.clock>=next_bot_population:
  next_bot_population=game.clock+1
  game.bot_population.maintain()
  if is_instance_valid(game.bots) and game.bots.ready_to_walk:game.bots.navigation.install_links();game.bots.navigation.update_jump_links()
 game.votes.tick()
 if game.clock>=next_control:
  next_control=game.clock+.25
  var control:Dictionary=game.votes.snapshot()
  if control!=last_control:
   last_control=control.duplicate(true)
   _control.rpc(epoch,control)
 # Admission and resource transfers continue through their existing Godot nodes.
 for id in game.pending_joins.keys():
  if game.clock>game.pending_joins[id]:game.multiplayer.multiplayer_peer.disconnect_peer(id)
 if not core.advance():push_error("Resident CQ tick contract rejected");game.get_tree().quit(2);return
 game.squads.roster=core.squad_roster()
 metrics=core.metrics()
 game.intermission=metrics.intermission;game.round_left=metrics.round_remaining;game.match_mode.scores=Array(metrics.scores)
 _publish()
 if adaptive_tick:
  var now:=Time.get_ticks_usec()
  var wall:=float(now-previous_tick_us)/1000000.0 if previous_tick_us>0 else delta
  previous_tick_us=now
  if not core.observe_tick_load(float(now-callback_start),wall):push_error("Adaptive CQ observation rejected");game.get_tree().quit(2)
func _publish()->void:
 var tick:int=metrics.snapshot_tick
 if tick==last_tick or tick<=0 or tick!=int(metrics.tick):return
 var frame:PackedByteArray=core.snapshot()
 if frame.is_empty():return
 last_tick=tick
 var packed:=frame.compress(FileAccess.COMPRESSION_FASTLZ);var parts:=ceili(packed.size()/960.)
 for id in game.multiplayer.get_peers():
  if not game.players.has(id) or game.loading.pending.has(id):continue
  for index in parts:_part.rpc_id(id,epoch,tick,index,parts,frame.size(),origin,packed.slice(index*960,mini((index+1)*960,packed.size())))
@rpc("authority","call_remote","unreliable",2)
func _part(map_epoch:int,tick:int,index:int,count:int,size:int,clock_origin:float,bytes:PackedByteArray)->void:
 if game.multiplayer.is_server() or map_epoch!=game.map_epoch or game.map_loading or not game.active:return
 if epoch!=map_epoch:reset_client();epoch=map_epoch
 if tick<=received_tick or tick<assembly_tick or not is_finite(clock_origin):return
 if count<1 or count>1093 or index<0 or index>=count or size<14 or size>Codec.MAX_FRAME or bytes.is_empty() or bytes.size()>960:return
 if tick!=assembly_tick:
  assembly_tick=tick;pieces.clear();pieces.resize(count);received_parts=0;packed_size=0;raw_size=size;assembly_origin=clock_origin
 if count!=pieces.size() or size!=raw_size or assembly_origin!=clock_origin or not pieces[index].is_empty():return
 pieces[index]=bytes;received_parts+=1;packed_size+=bytes.size()
 if packed_size>Codec.MAX_FRAME:return
 if received_parts!=count:return
 var packed:=PackedByteArray()
 for part in pieces:packed.append_array(part)
 var frame:Dictionary=Codec.decode_frame(packed.decompress(raw_size,FileAccess.COMPRESSION_FASTLZ))
 if frame.is_empty() or frame.tick!=tick or not frame.has("mode"):return
 var state:Array=Presentation.project(frame,assembly_origin,map_epoch,game.time_limit)
 if state.is_empty():return
 var mine:int=game.multiplayer.get_unique_id()
 var was_staging:bool=client_frame.get("players",{}).get(mine,{}).get("staging",false)
 client_frame=frame
 enabled=true;received_tick=tick;epoch=map_epoch;origin=assembly_origin
 state[11]=game.votes.view
 game.callv("_snapshot",state)
 if frame.players.has(mine):
  var local:Dictionary=frame.players[mine]
  if not local.owned.has(game.desired_weapon):game.desired_weapon=local.weapon
  if was_staging and not local.get("staging",false) and game.fighters.has(mine):
   var actor=game.fighters[mine];actor.prediction.clear();actor.position=local.position;actor.velocity=Vector3.ZERO;actor.reset_view();game.desired_weapon=local.weapon
   if game.is_vr():game.xr_rig.on_spawn()
 if not deployment_offered:
  deployment_offered=true
  if OS.get_cmdline_user_args().has("--authority-client-report"):request(10)
  elif game.loadout_menu:game.loadout_menu.begin_deployment()
 if frame.mode.intermission>0 and frame.mode.epoch!=last_round:game._round_end_gong(map_epoch);last_round=frame.mode.epoch
 effects(frame)
 for id in frame.players:
  var p:Dictionary=frame.players[id]
  if p.dead and game.fighters.has(id) and not death_effects.has(str(id)+":"+str(p.life)):death_fx(id,p.life,p.position+Vector3.UP,p.gibbed,Vector3.UP,100,0,"",false)
func effects(frame:Dictionary)->void:
 for seq in frame.get("events",{}):
  if seq<=last_event:continue
  var event:Dictionary=frame.events[seq];last_event=seq
  match event.kind:
   0:
    if event.detail not in [6,7,8]:game.night_vision.flash(event.position,18.,.08 if event.detail==9 else .14,.07 if event.detail==9 else .12)
    if game.players.has(event.actor):game._variant_shot_fx(event.actor,event.detail,false)
   1,2:
    if not game.headless:
     var definition:Dictionary=game.variant_combat.definition(event.actor,event.detail,{"battery_shot":event.detail==5 and event.value>10})
     game.spatial.play(game.projectile_sound(event.kind==2,event.detail),event.position,-8 if event.kind==2 else -18)
     game._weapon_visuals().burst("ut99",event.position,event.detail,definition.get("kind",""),definition)
   4:game._cq_airstrike_fx(event.position)
   5:
    if not game.headless and game.effects:game.effects.play("cq_field_ordnance_impact",event.position,-3)
   3:
    if event.actor==game.multiplayer.get_unique_id():game.recon_drone.alerts[event.actor]={"seq":seq,"life":event.life,"until":game.clock+event.value}
   6:game._melee_fx(event.actor,false)
   7:
    var end:Vector3=event.position+event.direction*event.value
    if event.detail==10:game._cq_beam_impacts(event.position,PackedVector3Array([end]),event.detail,int(event.entity))
    else:game._impacts(event.position,PackedVector3Array([end]),event.detail)
   8:game._de_grenade_fx(event.position,event.detail)
   9:
    if not game.players.has(event.actor) or game.players[event.actor].serial!=event.life:continue
    var dead:bool=bool(event.detail&1);var gibbed:bool=bool(event.detail&2);var blast:bool=bool(event.detail&4);var weapon:int=((event.detail>>4)&15)-1
    var name:String="BUILDING COLLAPSE" if ((event.detail>>8)&255)==11 else game.armory.data(weapon).name if weapon>=0 else "ENVIRONMENT"
    if dead:death_fx(event.actor,event.life,event.position,gibbed,event.direction,int(event.value),seq,name,blast)
    else:game._hurt_fx(event.actor,event.position,event.direction,int(event.value),false,false,seq,false,name,blast)
    if int(event.entity)==game.multiplayer.get_unique_id() and event.actor!=int(event.entity):game._hit_confirm(int(event.entity))
    if dead:
     var victim:String=game.players[event.actor].name;var killer:String=game.players.get(int(event.entity),{}).get("name",victim)
     game._announcement("%s  →  %s   ·   %s"%[killer,victim,name])

func utility(id:int,role:String,value:String)->bool:
 var index:int=Presentation.ROLES.find(role)
 if index<0:return false
 var tier:int=Presentation.UTILITY[index].find(value)+1
 return action(id,6,index,2,tier) if tier>0 else false
func nvg(id:int,life:int,map_epoch:int,seq:int)->bool:
 if epoch!=map_epoch or not core:return false
 var state:Dictionary=core.inspect(id)
 if state.is_empty() or state.life!=life or seq<=nvg_sequences.get(id,-1):return false
 nvg_sequences[id]=seq
 return action(id,1)
var nvg_sequences:Dictionary={}

func send_input(c:Dictionary)->void:
 var wire:Dictionary={"life":c.input_life,"seq":c.seq,"move":c.move,"yaw":c.yaw,"pitch":c.pitch,"weapon":c.weapon,"fire":c.fire,"jump":c.get("jump",false),"reload":c.get("reload",false),"slow":c.slow,"crouch":c.get("crouch",false),"prone":c.get("prone",false),"blocked":c.get("input_blocked",false),"view_time":float(c.get("view_time",-1.))-origin if c.get("view_time",-1.)>=0 else -1.}
 for key in ["xr","vr_device","room","reload_grip","reload_trigger","offhand_fire","jetpack","cq_drag","melee","respawn","weapon_held","jump_event","jump_seq","jetpack_event","fire_event"]:
  if c.has(key):wire[key]=c[key]
 _packet.rpc_id(1,game.map_epoch,Codec.encode_input(wire))
@rpc("any_peer","call_remote","unreliable_ordered",1)
func _packet(map_epoch:int,bytes:PackedByteArray)->void:
 if not serving() or not core or map_epoch!=epoch:return
 var id:int=multiplayer.get_remote_sender_id()
 if not lives.has(id) or not game.input_delivery.allow(id,game.clock):return
 native_peers[id]=true
 core.submit_packet(id,bytes)

func suicide(id:int,map_epoch:int,life:int)->bool:
 if epoch!=map_epoch or not core:return false
 var state:Dictionary=core.inspect(id)
 return action(id,7) if not state.is_empty() and state.life==life else false

var next_bot_population:=0.

func save_profile(id:int)->void:
 if not core:return
 var p:Dictionary=core.inspect(id)
 if p.is_empty():return
 var c:Dictionary=p.class_state;var saved:Dictionary=game.classes.ensure(id)
 saved.dispenser_ready=origin+c.box_ready;saved.cloak_ready=origin+c.cloak_ready;saved.drone_ready=origin+c.drone_ready;saved.airstrike_ready=origin+c.strike_ready;saved.turret_ready=origin+c.turret_ready
 saved["class"]=Presentation.ROLES[c.role];saved.next=Presentation.ROLES[c.next];saved.xp={};saved.primary_choices={};saved.secondary_choices={};saved.utility_choices={}
 for role in 4:
  var label:String=Presentation.ROLES[role];saved.xp[label]=c.xp[role];saved.primary_choices[label]=Presentation.ADVANCED[role] if c.primary&(1<<role) else Presentation.PRIMARY[role];saved.secondary_choices[label]=0 if c.secondary&(1<<role) else 8 if role==1 else 2;saved.utility_choices[label]=Presentation.UTILITY[role][int(bool(c.utility&(1<<role)))]
func reset_instance()->void:
 if core:
  for id in lives:save_profile(id)
 core=null;lives.clear();native_peers.clear();request_sequences.clear();action_sequences.clear();avatar_hashes.clear();nvg_sequences.clear();last_tick=-1
func reset_client()->void:
 deployment_offered=false
 client_frame.clear();received_tick=-1;assembly_tick=-1;pieces.clear();received_parts=0;packed_size=0;raw_size=0;last_event=0;last_round=-1;death_effects.clear();request_sequence=0;origin=0;epoch=-1;enabled=server_enabled
func reset()->void:
 deployed_peers.clear();reset_instance();reset_client()
func spawn_request(id:int)->bool:
 if not core or not lives.has(id):return false
 if game.players[id].spectator:detach(id);return false
 var state:Dictionary=core.inspect(id)
 if not state.is_empty() and state.team!=game.players[id].team:action(id,8,game.players[id].team)
 return true
func refresh_roster()->void:
 if not core:return
 for id in lives:
  var p:Dictionary=core.inspect(id)
  if p.is_empty() or not game.players.has(id):continue
  game.players[id].kills=p.kills;game.players[id].deaths=p.deaths;game.players[id].serial=p.life

func request(kind:int,a:int=0,b:int=0,c:int=0)->void:
 var state:Dictionary=game.local_state()
 if state.is_empty():return
 request_sequence+=1
 if game.multiplayer.is_server():_request(game.map_epoch,state.serial,request_sequence,kind,a,b,c)
 else:_request.rpc_id(1,game.map_epoch,state.serial,request_sequence,kind,a,b,c)
@rpc("any_peer","call_remote","reliable",0)
func _request(map_epoch:int,life:int,seq:int,kind:int,a:int=0,b:int=0,c:int=0)->void:
 if not serving() or not core or map_epoch!=epoch or kind not in [0,2,3,4,9,10,11,12] or seq<0 or seq>2147483647:return
 var id:int=multiplayer.get_remote_sender_id() if multiplayer.get_remote_sender_id()!=0 else multiplayer.get_unique_id()
 if not lives.has(id) or seq<=request_sequences.get(id,-1):return
 var state:Dictionary=core.inspect(id)
 if state.is_empty() or state.life!=life:return
 request_sequences[id]=seq
 if kind==10:
  # Automated test clients still enter through a mandatory bounded squad.
  action(id,11,-1);action(id,12,0)
 else:action(id,kind,a,b,c)

func death_fx(id:int,life:int,position:Vector3,gibbed:bool,direction:Vector3,damage:int,seed_value:int,weapon:String,blast:bool)->void:
 var key:=str(id)+":"+str(life)
 if death_effects.has(key):return
 death_effects[key]=true
 while death_effects.size()>2048:death_effects.erase(death_effects.keys()[0])
 game._hurt_fx(id,position,direction,damage,true,gibbed,seed_value,false,weapon,blast)

var next_control:=0.
var last_control:Dictionary={}
@rpc("authority","call_remote","reliable",0)
func _control(map_epoch:int,vote_state:Dictionary)->void:
 if map_epoch==game.map_epoch and not game.multiplayer.is_server():game.votes.view=vote_state
