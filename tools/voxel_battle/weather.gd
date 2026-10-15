extends Node3D
## Shared weather, local bounded GPU rain and procedural audio; no authoritative physics work.
const Schedule=preload("res://tools/voxel_battle/weather_schedule.gd")
var game
var seed_value:=-1
var seed_epoch:=-1
var seed_replies:Dictionary={}
var request_after:=0.
var rain:GPUParticles3D
var collider:GPUParticlesCollisionHeightField3D
var rain_sound:AudioStreamPlayer
var thunder_sound:AudioStreamPlayer3D
var environment:Environment
var state:Dictionary={}
var current_lightning:Dictionary={}
var scan:=0.
var sheltered:=false
var mean_frame:=.016
var pressure:=0.
var headroom:=0.
var reduced:=false
var last_thunder:=-1
var previous_time:=-1.
var preview_seed:=-1
var preview_time:=-1.
func setup(arena)->void:game=arena
func lighting():return game.battle_map.lighting if game.battle_map else null
func _process(delta:float)->void:
 if not game:return
 if not game.active:
  if seed_epoch>=0:reset()
  return
 if not lighting():return
 if preview_seed>=0:pass
 elif game.multiplayer.is_server():
  if seed_epoch!=game.map_epoch:
   seed_epoch=game.map_epoch
   if seed_value<0:seed_value=int(Crypto.new().generate_random_bytes(4).decode_u32(0)&0x7fffffff)
   seed_replies.clear()
 elif seed_epoch!=game.map_epoch and multiplayer.multiplayer_peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:
  request_after-=delta
  if request_after<=0:request_after=2.;_request_seed.rpc_id(1,game.map_epoch)
 var selected_seed:int=preview_seed if preview_seed>=0 else seed_value
 if selected_seed<0:return
 var seconds:float=preview_time if preview_time>=0 else lighting().cycle_time()
 state=Schedule.sample(selected_seed,seconds)
 if game.headless or DisplayServer.get_name()=="headless":return
 var camera:Camera3D=game.world_view_camera()
 if not camera:return
 if not rain:create_effects()
 var values:Vector4=state.values
 var strike:=Schedule.lightning(selected_seed,seconds)
 current_lightning=strike
 var flash:float=strike.flash*values.w
 lighting().weather_cloud=values.z;lighting().weather_flash=flash
 lighting().weather_lightning=Vector2(strike.angle,flash)
 var maximum:=1024 if game.is_vr() else 1536
 rain.amount_ratio=clampf(values.y*rain_budget(delta),0.,1.)
 rain.emitting=values.y>.01
 collider.visible=values.y>.01
 var eye:Vector3=camera.global_position
 rain.global_position=eye+Vector3(0,14,0)
 collider.global_position=Vector3(snappedf(eye.x,4),snappedf(eye.y+48,4),snappedf(eye.z,4))
 if rain.amount!=maximum:rain.amount=maximum
 var visor:bool="classes" in game and game.night_vision.enabled_for(game.multiplayer.get_unique_id())
 rain.draw_pass_1.material.albedo_color=Color(.09,.65,.17,.22) if visor else Color(.65,.75,.85,.32)
 environment=lighting().sky_environment
 if environment:
  environment.fog_enabled=true;environment.volumetric_fog_enabled=false
  environment.fog_density=values.x
  var daylight:float=lighting().light_fraction()
  environment.fog_light_color=Color(.025,.035,.055).lerp(Color(.47,.55,.6),daylight).lerp(Color(.65,.72,.85),flash*.7)
  environment.fog_light_energy=.6;environment.fog_sky_affect=.8
 scan-=delta
 if scan<=0:
  scan=.5
  sheltered=not game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,eye+Vector3.UP*144,1)).is_empty()
 var duck:float=.45 if game.voice and game.voice.transmitting else 1.
 rain_sound.volume_db=linear_to_db(maxf(.0001,values.y*(.18 if sheltered else .65)*duck))
 # Do not replay past claps on joins, clock corrections, or preview seeks.
 var audible_at:float=strike.at+strike.distance/343.
 if previous_time>=0 and seconds>=previous_time and seconds-previous_time<1. and previous_time<audible_at and seconds>=audible_at and strike.id>last_thunder and values.w>.5:
  last_thunder=strike.id
  thunder_sound.global_position=eye+Vector3(sin(strike.angle),.15,cos(strike.angle))*strike.distance
  thunder_sound.volume_db=-6 if sheltered else 0
  thunder_sound.play()
 previous_time=seconds
@rpc("any_peer","call_remote","reliable",0)
func _request_seed(epoch:int)->void:
 if not game.multiplayer.is_server() or epoch!=seed_epoch or not game.players.has(multiplayer.get_remote_sender_id()):return
 var id:=multiplayer.get_remote_sender_id()
 var now:=Time.get_ticks_msec()
 if now-int(seed_replies.get(id,-1000))<1000:return
 seed_replies[id]=now
 _receive_seed.rpc_id(id,seed_epoch,seed_value)
@rpc("authority","call_remote","reliable",0)
func _receive_seed(epoch:int,value:int)->void:
 if epoch!=game.map_epoch or value<0 or value>0x7fffffff:return
 if value!=seed_value:previous_time=-1;last_thunder=-1
 seed_epoch=epoch;seed_value=value;request_after=0.
func create_effects()->void:
 rain=GPUParticles3D.new();rain.name="LocalRain";rain.emitting=false;rain.amount=1536;rain.lifetime=1.15;rain.local_coords=false
 rain.visibility_aabb=AABB(Vector3(-25,-48,-25),Vector3(50,55,50));rain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var process:=ParticleProcessMaterial.new();process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;process.emission_box_extents=Vector3(20,1,20)
 process.direction=Vector3(.13,-1,.06);process.spread=3;process.initial_velocity_min=29;process.initial_velocity_max=36;process.gravity=Vector3(0,-8,0)
 process.collision_mode=ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
 rain.process_material=process
 var mesh:=QuadMesh.new();mesh.size=Vector2(.018,.65)
 # Hashed alpha turns each streak into opaque stipple, enlarged by XR VRS.
 # Soft blended streaks do not write noisy foreground depth over the scene.
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
 var gradient:=Gradient.new();gradient.set_color(0,Color.WHITE);gradient.set_color(1,Color(1,1,1,0))
 var mask:=GradientTexture2D.new();mask.width=16;mask.height=64;mask.gradient=gradient;mask.fill=GradientTexture2D.FILL_RADIAL;mask.fill_from=Vector2(.5,.5);mask.fill_to=Vector2(1,.5)
 material.albedo_texture=mask
 material.albedo_color=Color(.65,.75,.85,.32);material.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES;material.cull_mode=BaseMaterial3D.CULL_DISABLED
 mesh.material=material;rain.draw_pass_1=mesh;add_child(rain)
 collider=GPUParticlesCollisionHeightField3D.new();collider.size=Vector3(48,192,48);collider.resolution=GPUParticlesCollisionHeightField3D.RESOLUTION_256
 collider.update_mode=GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED;add_child(collider)
 rain_sound=AudioStreamPlayer.new();rain_sound.stream=load("res://deathmatch/audio/cq_field/rain.wav");rain_sound.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;rain_sound.stream.loop_begin=0;rain_sound.stream.loop_end=int(rain_sound.stream.get_length()*rain_sound.stream.mix_rate);rain_sound.bus="ArenaAmbience" if AudioServer.get_bus_index("ArenaAmbience")>=0 else "Master";rain_sound.volume_db=-80;add_child(rain_sound);rain_sound.play()
 thunder_sound=AudioStreamPlayer3D.new();thunder_sound.stream=load("res://deathmatch/audio/cq_field/thunder.wav");thunder_sound.bus=rain_sound.bus;thunder_sound.unit_size=300;thunder_sound.max_distance=1600;add_child(thunder_sound)
func lightning_source(eye:Vector3)->Dictionary:
 if current_lightning.is_empty() or not lighting() or lighting().weather_flash<=.001:return {}
 var distance:float=current_lightning.distance
 var direction:=Vector3(sin(current_lightning.angle),.28,cos(current_lightning.angle)).normalized()
 return {"id":current_lightning.id,"position":eye+direction*distance,"radius":distance*.22,"strength":clampf(lighting().weather_flash,0.,1.)}
func rain_budget(delta:float)->float:
 # Adapt rain cost, never fog visibility, to sustained local render pressure.
 mean_frame=lerpf(mean_frame,minf(delta,.1),1-exp(-delta/2.))
 pressure=pressure+delta if mean_frame>.022 else 0.
 headroom=headroom+delta if mean_frame<.015 else 0.
 if pressure>2:reduced=true
 if headroom>10:reduced=false
 return .4 if reduced else 1.
func reset()->void:
 seed_value=-1;seed_epoch=-1;request_after=0.;previous_time=-1;last_thunder=-1;state.clear();current_lightning.clear();seed_replies.clear()
 if rain:rain.emitting=false
 if collider:collider.visible=false
 if rain_sound:rain_sound.volume_db=-80
 if thunder_sound:thunder_sound.stop()
 clear_lighting()
func clear_lighting()->void:
 if rain and game and is_instance_valid(game.battle_map) and lighting():
  lighting().weather_cloud=0.;lighting().weather_flash=0.;lighting().weather_lightning=Vector2.ZERO
 if environment:environment.fog_enabled=false

func _exit_tree()->void:clear_lighting()
