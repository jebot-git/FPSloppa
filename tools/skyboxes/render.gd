extends SceneTree
const Atmosphere=preload("res://deathmatch/maps/atmosphere.gd")
const Catalog=preload("res://deathmatch/maps/skies/catalog.gd")
const OUT="res://test-results/skyboxes/render/"
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func vec(value: Array) -> Vector3:return Vector3(value[0],value[1],value[2])
func metrics(values: Array) -> Dictionary:
 values.sort();return {"median":values[values.size()/2],"p95":values[int(values.size()*.95)]}
func previous_sky(map: String) -> Sky:
 var profile: Array=Atmosphere.PROFILES[Atmosphere.MAPS[map]]
 var mat:=ProceduralSkyMaterial.new();mat.sky_top_color=profile[0];mat.sky_horizon_color=profile[1]
 mat.ground_horizon_color=profile[1];mat.ground_bottom_color=profile[0];mat.sun_angle_max=8
 var sky:=Sky.new();sky.sky_material=mat;sky.process_mode=Sky.PROCESS_MODE_QUALITY;sky.radiance_size=Sky.RADIANCE_SIZE_128
 return sky
func run() -> void:
 if DisplayServer.get_name()=="headless":quit(2);return
 DirAccess.make_dir_recursive_absolute(OUT)
 root.size=Vector2i(960,600);root.content_scale_size=root.size
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=120
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.hud.hide();game.voice.set_mode(0)
 root.msaa_3d=Viewport.MSAA_4X
 var viewport:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
 var audit: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://test-results/skyboxes/map-audit.json"))
 var results: Array=[]
 for row in audit.maps:
  if not Catalog.MAPS.has(row.id):continue
  check(game._load_map(row.id),row.id+": map loads")
  for node in game.get_node("Map").find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
  var camera: Camera3D=game.get_node("Overview");game.camera=camera
  camera.position=vec(row.views[0].eye);camera.look_at(vec(row.views[0].target));camera.make_current()
  check(game.get_node("Map/MapRuntime").contents.at(camera.position)==-1,row.id+": eye in empty world space")
  var world: WorldEnvironment=game.get_node("Environment")
  var current: Environment=world.environment
  check(current.sky.sky_material is PanoramaSkyMaterial,row.id+": selected panorama active")
  var before:=current.duplicate() as Environment;before.sky=previous_sky(row.id)
  for variant in ["before","after"]:
   world.environment=before if variant=="before" else current
   for i in 30:await process_frame
   var gpu: Array=[];var draws: Array=[]
   for i in 45:
    await process_frame
    gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport));draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT+row.id+"-"+variant+".png")
   results.append({"map":row.id,"variant":variant,"gpu_ms":metrics(gpu),"draws":metrics(draws),"eye":row.views[0].eye})
  print("SKY_RENDER ",row.id)
  FileAccess.open(OUT+"results.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"records":results,"failures":failures},"  "))
  before=null;current=null
 game.queue_free();for i in 3:await process_frame
 print("SKY_RENDER_RESULT ",failures);quit(0 if failures.is_empty() else 1)
