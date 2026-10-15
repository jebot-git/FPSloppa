extends SceneTree
## Rendered real-map weather receipts; no gameplay or service changes.
const Weather=preload("res://tools/voxel_battle/weather.gd")
const Schedule=preload("res://tools/voxel_battle/weather_schedule.gd")
const OUTPUT:="res://test-results/weather"
var scene
var running:=false
class ViewGame extends Node3D:
 var active:=true
 var headless:=false
 var map_epoch:=0
 var battle_map
 var camera:Camera3D
 var voice=null
 var weather
 var night_vision=preload("res://deathmatch/conquest/classes/night_vision.gd").new()
 func world_view_camera()->Camera3D:return camera
 func is_vr()->bool:return false
class VisorPreview extends Node:
 var game
 var effect
 var active:=false
 func _process(_delta:float)->void:
  if not active:return
  effect.enabled=true
  effect.configure(6000,false,0,Time.get_ticks_msec()/1000.,0,game.night_vision.flash_samples(game.camera.global_transform))
func _initialize()->void:run.call_deferred()
func _process(_delta:float)->bool:
 if running:scene.map.update_view(scene.camera)
 return false
func run()->void:
 if DisplayServer.get_name()=="headless":quit(1);return
 DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1280,800)
 scene=load("res://tools/voxel_battle/jungle_preview.tscn").instantiate();scene.benchmarks=true;root.add_child(scene);scene.panel.visible=false
 var game:=ViewGame.new();game.battle_map=scene.map;game.camera=scene.camera;scene.add_child(game)
 var weather:=Weather.new();weather.name="Weather";game.add_child(weather);weather.setup(game);weather.preview_seed=42;game.weather=weather;game.night_vision.setup(game)
 var visor:=VisorPreview.new();visor.game=game;visor.effect=scene.visor_effect;game.add_child(visor)
 scene.map.lighting.phase_override=1.
 var center:Vector3=scene.Landscape.CENTERS[4]
 scene.camera.position=center+Vector3(0,8,110);scene.camera.look_at(center+Vector3(0,6,0));running=true
 var begin:=Time.get_ticks_msec()
 while not scene.map.terrain.settled():
  await process_frame
  if Time.get_ticks_msec()-begin>90000:push_error("Weather preview stream timeout");quit(1);return
 var title:=Label.new();title.position=Vector2(20,20);title.add_theme_font_size_override("font_size",26);root.add_child(title)
 var records:Array=[]
 var used:Dictionary={}
 for day in 80:
  var time:=Schedule.change_offset(42)+day*Schedule.DAY_SECONDS+60.
  var mode:int=Schedule.sample(42,time).mode
  if used.has(mode):continue
  used[mode]=true;weather.preview_time=time;title.text=Schedule.NAMES[mode].to_upper()
  await create_timer(2).timeout
  var timings:Array=[]
  for frame in 120:
   var before:=Time.get_ticks_usec();await process_frame;timings.append((Time.get_ticks_usec()-before)/1000.)
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OUTPUT+"/"+str(mode)+".png")
  timings.sort()
  records.append({"mode":mode,"weather":Schedule.NAMES[mode],"p50_ms":timings[60],"p95_ms":timings[114],"rain_particles":weather.rain.amount,"reduced":weather.reduced,"density":weather.environment.fog_density,"rain_intensity":weather.state.values.y})
  if mode==3:
   var flash:=Schedule.lightning(42,time)
   weather.preview_time=flash.at+.045;title.text="THUNDERSTORM · LIGHTNING"
   scene.camera.global_position+=Vector3.UP*70
   var eye:Vector3=scene.camera.global_position
   scene.camera.look_at(eye+Vector3(sin(flash.angle),.23,cos(flash.angle)))
   await create_timer(.1).timeout
   await process_frame;await process_frame;await RenderingServer.frame_post_draw
   assert(weather.game.battle_map.lighting.weather_flash>.8,"Lightning flash reaches baked-lighting bridge")
   root.get_texture().get_image().save_png(OUTPUT+"/lightning.png")
   var clap:float=flash.at+flash.distance/343.
   weather.preview_time=clap-.02;weather._process(.016)
   weather.preview_time=clap+.02;weather._process(.04)
   assert(weather.thunder_sound.playing,"Synchronized flash produces delayed thunder")
   weather.thunder_sound.stop()
   weather.preview_time=clap-.02;weather._process(.016)
   weather.preview_time=clap+.02;weather._process(.04)
   assert(not weather.thunder_sound.playing,"Clock correction does not replay the same clap")
  if used.size()==4:break
 assert(used.size()==4)
 scene.map.lighting.phase_override=0.;title.text="THUNDERSTORM · NIGHT"
 weather.preview_time+=1.
 await create_timer(.3).timeout;await process_frame;await RenderingServer.frame_post_draw
 assert(weather.environment.fog_light_color.r<.1,"Fog adapts to night lighting")
 root.get_texture().get_image().save_png(OUTPUT+"/night.png")
 var event:=Schedule.lightning(42,weather.preview_time)
 weather.preview_time=event.at+.045;visor.active=true;title.text="NVG · LIGHTNING GLARE"
 await create_timer(.15).timeout;await RenderingServer.frame_post_draw
 var glare:=root.get_texture().get_image();glare.save_png(OUTPUT+"/nvg-lightning.png")
 assert(not game.night_vision.flash_samples(scene.camera.global_transform).is_empty(),"Lightning feeds the visor's angular exposure sources")
 assert(glare.get_pixel(root.size.x/2,root.size.y/2).r>.7,"Lightning blooms white in the actual NVG compute pass")
 weather.preview_time=event.at+1.;title.text="NVG · RECOVERED"
 await create_timer(.85).timeout;await RenderingServer.frame_post_draw
 var recovered:=root.get_texture().get_image();recovered.save_png(OUTPUT+"/nvg-recovered.png")
 assert(game.night_vision.flash_samples(scene.camera.global_transform).is_empty(),"NVG recovers after the flash")
 assert(recovered.get_pixel(root.size.x/2,root.size.y/2).r<.3,"NVG white glare decays in the rendered image")
 visor.active=false;scene.visor_effect.enabled=false
 assert(weather.rain_sound.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD)
 FileAccess.open(OUTPUT+"/results.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"cases":records},"\t"))
 running=false;scene.map.terrain.shutdown();scene.free();scene=null;await process_frame
 await create_timer(.5).timeout
 print("CQ_WEATHER_RENDER_PASS ",JSON.stringify(records));quit()
