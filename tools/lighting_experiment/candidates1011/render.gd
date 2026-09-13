extends SceneTree
const C=preload("res://tools/lighting_experiment/candidates1011/common.gd")
const Variants=preload("res://tools/lighting_experiment/candidates1011/variants.gd")
var failures: Array=[]
var records: Array=[]
var world: Node3D
var camera: Camera3D
var contents
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func geometry(level: Node) -> PackedByteArray:
 var values: Array=[]
 for node in level.find_children("*","MeshInstance3D",true,false):
  if node.mesh:
   for i in node.mesh.get_surface_count():values.append([node.transform,node.mesh.surface_get_arrays(i)])
 for node in level.find_children("*","CollisionShape3D",true,false):values.append([node.transform,node.shape.get_debug_mesh().get_faces()])
 var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes(values));return h.finish()
func material_view(level: Node,map: String,name: String) -> Array:
 var choices: Array=[]
 for node in level.find_children("*","MeshInstance3D",true,false):
  if not node.mesh:continue
  for surface in node.mesh.get_surface_count():
   var mat: Material=node.get_active_material(surface)
   if not mat or mat.get_meta("bsp_texture_name","")!=name:continue
   var a: Array=node.mesh.surface_get_arrays(surface);var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var ids: PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
   if ids.is_empty():ids=PackedInt32Array(range(v.size()))
   for j in range(0,ids.size(),3):
    var point: Vector3=node.global_transform*((v[ids[j]]+v[ids[j+1]]+v[ids[j+2]])/3.0)
    var normal: Vector3=(node.global_basis*a[Mesh.ARRAY_NORMAL][ids[j]]).normalized()
    var area: float=(v[ids[j+1]]-v[ids[j]]).cross(v[ids[j+2]]-v[ids[j]]).length()
    choices.append({"p":point,"n":normal,"score":area/(1+point.distance_squared_to(C.PROBES[map]))})
 choices.sort_custom(func(a,b):return a.score>b.score)
 for row in choices:
  for distance in [3.0,1.5,5.0]:
   var eye: Vector3=row.p+row.n*distance
   if contents.at(eye)!=-1:continue
   var hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,row.p-row.n*.1,1))
   if hit.is_empty() or hit.position.distance_to(eye)<distance-.15:continue
   return [eye,row.p,"metal"]
 check(false,map+": no valid metal view");return []
func shot(view: Array) -> void:
 camera.position=view[0];camera.look_at(view[1],Vector3.FORWARD if absf((view[1]-view[0]).normalized().dot(Vector3.UP))>.98 else Vector3.UP)
func run() -> void:
 assert(DisplayServer.get_name()!="headless")
 var setup:=C.setup(self,Vector2i(1280,800));world=setup[0];camera=setup[1]
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 var viewport:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
 var visual: Array=[]
 for map in C.PROBES:
  contents=C.Contents.new();check(contents.open("res://maps/"+map+".bsp"),map+": BSP available")
  C.Atlas.apply(world,map);check(not world.get_node("Environment").environment.fog_enabled,map+": fog absent")
  var source:=C.scene(map);world.add_child(source);C.still(source)
  await physics_frame;await physics_frame
  var expected:=geometry(source)
  var views: Array=[[Vector3(15,2.2,24),Vector3(-8,12,-28),"nave"],[Vector3(15,1.6,24),Vector3(8,0,18),"floor"],material_view(source,map,"metal_brnz_01")] if map=="tf_vesper" else [[Vector3(16.25,2.2,23.75),Vector3(0,5.6,-9.4),"turbine"],[Vector3(16.25,1.7,23.75),Vector3(7,0,12),"floor"],material_view(source,map,"metal_iron1_07")]
  source.free();await process_frame
  for contrast in [false,true]:
   var mode: String="contrast" if contrast else "classic";DirAccess.make_dir_recursive_absolute(C.OUT+mode)
   for variant in ["baseline","flat","reflection","directional","strong","combined","restored"]:
    var level:=C.scene(map);world.add_child(level);C.still(level,contrast)
    var resources:=Variants.apply(level,map,variant,contrast)
    check(geometry(level)==expected,map+" "+variant+": vertices UVs normals collision unchanged")
    for view in views:
     if view.is_empty():continue
     check(contents.at(view[0])==-1,map+" "+view[2]+": camera outside solid")
     shot(view)
     for i in 40:await process_frame
     var gpu: Array=[];var cpu: Array=[];var draws: Array=[];var memory: Array=[]
     for i in 150:
      await process_frame
      gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport));cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport));draws.append(RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME));memory.append(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png(C.OUT+mode+"/"+map+"-"+view[2]+"-"+variant+".png")
     records.append({"map":map,"view":view[2],"mode":mode,"variant":variant,"gpu_ms":C.stats(gpu),"cpu_ms":C.stats(cpu),"draws":C.stats(draws),"texture_bytes":C.stats(memory),"resources":resources,"eye":str(view[0]),"target":str(view[1])})
     if contrast and view[2]=="floor" and variant in ["baseline","reflection","directional","combined"]:
      var right:=camera.global_basis.x
      for offset in [-.32,-.032,.032,.32]:
       var eye: Vector3=view[0]+right*offset
       check(contents.at(eye)==-1,map+": offset camera outside solid")
       camera.position=eye # Same orientation: pure lateral motion / 64 mm eye pair.
       for i in 8:await process_frame
       await RenderingServer.frame_post_draw
       var file: String=map+"-motion-"+variant+"-"+str(offset)+".png"
       root.get_texture().get_image().save_png(C.OUT+mode+"/"+file);visual.append({"map":map,"variant":variant,"offset_m":offset,"file":file})
    level.free();for i in 4:await process_frame
   print("CANDIDATES1011_RENDER ",map," ",mode)
   FileAccess.open(C.OUT+"render.json",FileAccess.WRITE).store_string(JSON.stringify({"records":records,"motion":visual,"failures":failures,"measured_frames":records.size()*150,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1280,800],"msaa":4,"fog":false,"runtime_captures":false},"  "))
 world.free();contents=null;for i in 3:await process_frame
 print("CANDIDATES1011_RENDER_RESULT ",failures);quit(0 if failures.is_empty() else 1)
