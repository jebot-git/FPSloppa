extends SceneTree
const OUT="res://test-results/candidates789/"
const Contents=preload("res://deathmatch/maps/contents.gd")
const Atmosphere=preload("res://deathmatch/maps/atmosphere.gd")
var failures: Array=[]
var records: Array=[]
var world: Node3D
var camera: Camera3D
var contents
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func stats(values: Array) -> Dictionary:
 values.sort();return {"median":values[values.size()/2],"p95":values[int(values.size()*.95)]}
func still(level: Node) -> void:
 var seen: Dictionary={}
 for node in level.find_children("*","Node",true,false):
  node.set_process(false);node.set_physics_process(false)
  if node is MeshInstance3D and node.mesh:
   for i in node.mesh.get_surface_count():
    var mat: Material=node.get_active_material(i)
    if mat is ShaderMaterial and mat.get_shader_parameter("bake_texture") is Texture2D and not seen.has(mat):
     seen[mat]=true;mat.set_shader_parameter("liquid_warp",false);mat.set_shader_parameter("map_uv_offset",Vector2.ZERO);mat.set_shader_parameter("contrast_lighting",false);mat.set_shader_parameter("surface_variation",true)
func material_view(level: Node,name: String,label: String) -> Array:
 var triangles: Array=[]
 for node in level.find_children("*","MeshInstance3D",true,false):
  if not node.mesh:continue
  for i in node.mesh.get_surface_count():
   var mat: Material=node.get_active_material(i)
   if not mat or mat.get_meta("bsp_texture_name","")!=name:continue
   var glow: Texture2D=mat.get_shader_parameter("glow_texture") if mat is ShaderMaterial else null
   var glow_image: Image=glow.get_image() if glow else null
   var a: Array=node.mesh.surface_get_arrays(i);var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var ids: PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array(range(v.size()))
   if ids.is_empty():ids=PackedInt32Array(range(v.size()))
   for j in range(0,ids.size(),3):
    var p: Vector3=node.global_transform*((v[ids[j]]+v[ids[j+1]]+v[ids[j+2]])/3.0)
    var normal: Vector3=(node.global_basis*a[Mesh.ARRAY_NORMAL][ids[j]]).normalized()
    var area: float=(v[ids[j+1]]-v[ids[j]]).cross(v[ids[j+2]]-v[ids[j]]).length()
    if name=="tlight12" and glow_image:
     # Aim at an actual emissive UV region rather than the fixture's casing.
     for u in range(1,8):
      for w in range(1,8-u):
       var weights:=Vector3(u,w,8-u-w)/8.0
       var uv: Vector2=a[Mesh.ARRAY_TEX_UV][ids[j]]*weights.x+a[Mesh.ARRAY_TEX_UV][ids[j+1]]*weights.y+a[Mesh.ARRAY_TEX_UV][ids[j+2]]*weights.z
       var colour:=glow_image.get_pixel(int(fposmod(uv.x,1.0)*glow_image.get_width()),int(fposmod(uv.y,1.0)*glow_image.get_height()))
       if maxf(colour.r,maxf(colour.g,colour.b))<.1:continue
       var point: Vector3=node.global_transform*(v[ids[j]]*weights.x+v[ids[j+1]]*weights.y+v[ids[j+2]]*weights.z)
       triangles.append({"point":point,"normal":normal,"area":area})
    else:triangles.append({"point":p,"normal":normal,"area":area})
 triangles.sort_custom(func(a,b):return a.area>b.area)
 for row in triangles:
  for distance in [3.0,5.0,1.5,8.0]:
   var eye: Vector3=row.point+row.normal*distance
   if contents.at(eye)!=-1:continue
   var query:=PhysicsRayQueryParameters3D.create(eye,row.point-row.normal*.1,1)
   var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
   if not hit.is_empty() and hit.position.distance_to(eye)<distance-.15:continue
   return [eye,row.point,label]
 check(false,"No valid visible viewpoint for "+label);return []
func spawn_view(level: Node,last: bool) -> Array:
 var points: Array=[]
 for node in level.get_children():
  if "attributes" in node and node.attributes.get("classname","")=="info_player_deathmatch":
   var eye: Vector3=node.position+Vector3.UP*.78
   if contents.at(eye)==-1:points.append(eye)
 if points.is_empty():check(false,"Missing spawn viewpoints");return []
 var eye: Vector3=points.back() if last else points[0];var best:=Vector3.FORWARD;var distance:=-1.0
 for i in 32:
  var direction:=Vector3(sin(i*TAU/32),-.10,cos(i*TAU/32)).normalized()
  var hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,eye+direction*60,1))
  var reach: float=-1 if hit.is_empty() else eye.distance_to(hit.position)
  if reach>distance:distance=reach;best=direction
 return [eye,eye+best*20,"corridor"+str(int(last))]
func run() -> void:
 if DisplayServer.get_name()=="headless":quit(1);return
 var output:=OUT+"mobile/";DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1280,800);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 world=Node3D.new();root.add_child(world)
 var template: Node=load("res://deathmatch/arena.tscn").instantiate()
 world.add_child(template.get_node("Environment").duplicate());var sun: DirectionalLight3D=template.get_node("DuskSun").duplicate();sun.light_energy=.25;sun.shadow_enabled=false;world.add_child(sun);template.free()
 camera=Camera3D.new();world.add_child(camera);camera.fov=70;camera.make_current()
 var viewport:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
 var capabilities:={"bptc":RenderingServer.has_os_feature("bptc"),"astc":RenderingServer.has_os_feature("astc")}
 print("CANDIDATE_GPU_CAPABILITIES ",capabilities)
 for map in ["tf_pressureworks","tf_vesper","qsrc_dm2","ctf_deepvault"]:
  contents=Contents.new();check(contents.open("res://maps/"+map+".bsp"),map+": contents available")
  Atmosphere.apply(world,map)
  var source: Node=ResourceLoader.load(OUT+"cache/"+map+"-baseline.scn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate();world.add_child(source)
  await physics_frame;await physics_frame
  var views: Array=[]
  if map=="tf_pressureworks":views=[[Vector3(16.25,2.2,23.75),Vector3(0,5.6,-9.4),"turbine"],[Vector3(16.25,1.7,23.75),Vector3(7,0,12),"floor"],material_view(source,"tlight12","lamp")]
  elif map=="tf_vesper":views=[[Vector3(15,2.2,24),Vector3(-8,12,-28),"nave"],[Vector3(6,1.7,21),Vector3(0,0,11),"arch_floor"],material_view(source,"stn_gr01_blu1","rose")]
  elif map=="qsrc_dm2":views=[material_view(source,"*lava1","lava"),material_view(source,"rune2_1","runes"),spawn_view(source,false)]
  else:views=[spawn_view(source,false),spawn_view(source,true)]
  source.free();await process_frame
  var variants: Array=["baseline","baseline-packed","authored","packed_glow","bc7_colour","bc7_all","astc4_colour","astc4_all","astc8_all","half_colour","bc7_large","astc4_large"]
  if map.begins_with("tf_"):variants.append("density-packed")
  variants.append("baseline")
  for index in variants.size():
   var variant: String=variants[index];var label: String="restored" if index==variants.size()-1 else variant
   var level: Node=ResourceLoader.load(OUT+"cache/"+map+"-"+variant+".scn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate();world.add_child(level);still(level)
   for view in views:
    if view.is_empty():continue
    check(contents.at(view[0])==-1,map+" "+view[2]+": camera outside solid BSP")
    camera.position=view[0];camera.look_at(view[1],Vector3.FORWARD if absf((view[1]-view[0]).normalized().dot(Vector3.UP))>.98 else Vector3.UP)
    for i in 45:await process_frame
    var gpu: Array=[];var cpu: Array=[];var draws: Array=[];var memory: Array=[]
    for i in 120:
     await process_frame
     gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport));cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport));draws.append(RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME));memory.append(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output+map+"-"+view[2]+"-"+label+".png")
    records.append({"map":map,"view":view[2],"eye":str(view[0]),"target":str(view[1]),"variant":label,"gpu_ms":stats(gpu),"cpu_ms":stats(cpu),"draws":stats(draws),"texture_bytes":stats(memory),"astc_decoded_reference":variant.begins_with("astc")})
   print("CANDIDATE_RENDER ",map," ",label)
   level.free();for i in 3:await process_frame
   FileAccess.open(output+"render.json",FileAccess.WRITE).store_string(JSON.stringify({"records":records,"failures":failures},"  "))
 var report:={"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"capabilities":capabilities,"resolution":[1280,800],"msaa":4,"contrast_lighting":false,"measured_frames":records.size()*120,"records":records,"failures":failures}
 FileAccess.open(output+"render.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 world.free();await load("res://tools/lighting_experiment/candidates789/materials.gd").new().run(self)
 print("CANDIDATE_RENDER_RESULT ",failures);quit(0 if failures.is_empty() else 1)
