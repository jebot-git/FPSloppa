extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const OUT="res://test-results/map-presentation/"
var rows: Array=[]
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func stats(values: Array) -> Dictionary:
 values.sort();return {"median":values[values.size()/2],"p95":values[int(values.size()*.95)]}
func baked_materials(level: Node) -> Array:
 var filter:=Filtering.new();filter.apply(level,2,true,1)
 return filter.materials.keys().filter(func(mat):return mat is ShaderMaterial and mat.shader==Filtering.BAKED)
func run() -> void:
 if DisplayServer.get_name()=="headless":quit(1);return
 var output:=OUT+"mobile/";DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.hud.hide();game.voice.set_mode(0)
 game.presentation.texture_filter=2;game.presentation.contrast_lighting=true
 root.msaa_3d=Viewport.MSAA_4X;root.scaling_3d_scale=1
 var viewport:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
 var chosen: Array=["tf_pressureworks","tf_vesper","as_hislop","koth_hyperborea","cc_basement","qsrc_dm2","qsrc_dm7","ctf_deepvault","external-optin"]
 for map in chosen:
  var path: String="res://maps/"+map+".bsp"
  if map=="external-optin":path="res://test-results/lighting-coverage/external-optin.bsp"
  var hash:=FileAccess.get_sha256(path)
  if map!="external-optin":
   DirAccess.make_dir_recursive_absolute(OUT+"runtime-cache")
   var base_path: String=OUT+"runtime-cache/"+map
   for suffix in [".scn","-lightmap1.scn","-lightmap1-textures-"+load("res://deathmatch/maps/texture_replacements/dictionary.gd").version()+".scn"]:
    DirAccess.copy_absolute(OUT+"cache/"+map+".scn",base_path+suffix)
  game.match_mode.kind="dm";game.map_catalog=[{"id":map,"title":map,"path":path,"sha256":hash,"scene":OUT+"runtime-cache/"+map+".scn"}]
  check(game._load_map(map),map+": loads")
  var level: Node=game.get_node("Map").get_child(0)
  var materials:=baked_materials(level)
  check(not materials.is_empty(),map+": baked surfaces")
  var motion: Node=game.get_node("Map/MapRuntime/SurfaceMotion")
  for node in game.get_node("Map").find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
  var camera: Camera3D=game.get_node("Overview");game.camera=camera
  var views: Array=[]
  if map=="tf_pressureworks":views=[[Vector3(16.25,2.2,23.75),Vector3(0,5.6,-9.4),"turbine"],[Vector3(-7.5,1.7,-51.25),Vector3(0,1.25,-55.5),"flag"]]
  elif map=="tf_vesper":views=[[Vector3(15,2.2,24),Vector3(-8,12,-28),"nave"],[Vector3(7,9.7,-50),Vector3(9.5,9.2,-58.5),"sanctuary"]]
  else:
   await physics_frame;await physics_frame
   var usable: Array=[]
   for point in game.spawn_points:
    var eye: Vector3=point+Vector3.UP*1.48
    if game.get_node("Map/MapRuntime").contents.at(eye)==-2:continue
    var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,eye-Vector3.UP*64,1))
    if not hit.is_empty():usable.append(point)
   check(usable.size()>=2,map+": usable viewpoints")
   if usable.size()<2:continue
   var first: Vector3=usable[0];var farthest: Vector3=first
   for point in usable:
    if point.distance_squared_to(first)>farthest.distance_squared_to(first):farthest=point
   for view_index in 2:
    var eye: Vector3=(first if view_index==0 else farthest)+Vector3.UP*1.48
    var best:=Vector3.FORWARD;var distance:=-1.0
    for n in 24:
     var direction:=Vector3(sin(n*TAU/24),-.12,cos(n*TAU/24)).normalized()
     var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,eye+direction*40,1))
     var reach: float=-1.0 if hit.is_empty() else eye.distance_to(hit.position)
     if reach>distance:distance=reach;best=direction
    views.append([eye,eye+best*20,"spawn"+str(view_index)])
  check(views.size()==2,map+": two views")
  for view in views:
   check(game.get_node("Map/MapRuntime").contents.at(view[0])!=-2,map+": camera outside solid BSP at "+str(view[2]))
   camera.position=view[0];camera.look_at(view[1]);camera.make_current()
   game.get_node("Map/MapRuntime")._process(1.0)
   var variants: Array=["baseline","atmosphere","animation","variation","combined","combined","restored"]
   for pass_index in variants.size():
    var variant: String=variants[pass_index]
    motion.apply({"map_atmosphere":variant in ["atmosphere","combined"],"surface_animation":variant in ["animation","combined"],"surface_variation":variant in ["variation","combined"]})
    for i in 25:await process_frame
    var gpu: Array=[];var cpu: Array=[];var draws: Array=[];var textures: Array=[]
    for i in 90:
     await process_frame
     gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport));cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
     draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));textures.append(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
    rows.append({"map":map,"view":view[2],"variant":variant,"pass":pass_index,"gpu_ms":stats(gpu),"cpu_ms":stats(cpu),"draws":stats(draws),"texture_bytes":stats(textures)})
    if pass_index!=5:
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png(output+map+"-"+view[2]+"-"+variant+".png")
   print("PRESENTATION_RENDER ",map," ",view[2])
   FileAccess.open(output+"render.json",FileAccess.WRITE).store_string(JSON.stringify({"records":rows,"failures":failures},"  "))
 var report:={"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"resolution":[1280,800],"msaa":4,"measured_frames":rows.size()*90,"records":rows,"failures":failures}
 FileAccess.open(output+"render.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 game.queue_free();for i in 3:await process_frame
 print("PRESENTATION_RENDER_RESULT ",failures);quit(0 if failures.is_empty() else 1)
