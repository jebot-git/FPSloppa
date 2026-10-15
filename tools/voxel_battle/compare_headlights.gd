extends SceneTree
## Full-map render comparison. Source materials are cloned only in this process.
const Map=preload("res://tools/voxel_battle/map.gd")
const Transport=preload("res://deathmatch/conquest/classes/transport_geometry.gd")
const OUTPUT:="res://test-results/headlight-comparison"
var world:Node3D
var map
var camera:Camera3D
var vehicle:Node3D
var avatar:Node3D
var lenses:Array=[]
var materials:Array=[]
var converted:Dictionary={}
var shaders:Dictionary={}
var frames:Array=[]
var sample_label:=""
var last_post:=0
var frozen:=false
func _initialize()->void:run.call_deferred()
func insert_vertex(source:String,code:String)->String:
 var start:=source.find("void vertex(")
 if start<0:return source+"\nvoid vertex(){"+code+"}\n"
 var brace:=source.find("{",start);var depth:=1;var cursor:=brace+1
 while depth>0:
  if source[cursor]=="{":depth+=1
  elif source[cursor]=="}":depth-=1
  cursor+=1
 return source.insert(cursor-1,code)
func material(original:Material)->Material:
 if not original is ShaderMaterial or original.has_meta("headlight_probe"):return original
 if converted.has(original.get_instance_id()):return converted[original.get_instance_id()]
 var path:String=original.shader.resource_path
 var name:String=path.get_file();var source:String=original.shader.code;var point:="";var family:="surface"
 if name in ["vertex_animation.gdshader","vertex_lighting.gdshader"]:
  source="shader_type spatial;\n"+FileAccess.get_file_as_string("res://deathmatch/avatars/vertex_animation.gdshaderinc")
 # Keep the reference fragment-baked avatar path here; vertex-baked optimisation has its own probe.
 # Probe controls sampling independently of production headlight globals.
 source=source.replace("cq_headlight(","headlight_value(")
 source=source.replace("cq_terrain_lamp=headlight_value(jungle_point);","cq_terrain_lamp=vec3(0.0);")
 match name:
  "baked_surface.gdshader", "baked_card.gdshader":point="point"
  "terrain.gdshader":
   point="jungle_point";family="terrain";source=source.replace("+cq_terrain_lamp;","+headlight_value(jungle_point);")
  "transport_hull.gdshader", "water.gdshader":point="world_point"
  "tree_svo.gdshader":point="(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz"
  "vertex_animation.gdshader", "vertex_lighting.gdshader":point="jungle_point";family="avatar"
  _:return original
 assert(source.contains("headlight_value("),"Receiver patch missing: "+path)
 if not shaders.has(path):
  source=source.replace("shader_type spatial;","shader_type spatial;\n#include \"res://tools/voxel_battle/headlight_probe.gdshaderinc\"")
  var vertex_code:String="headlight_vertex=(headlights_on && !headlights_per_pixel)?headlight_sample("+point+"):vec3(0.0);"
  if family=="terrain":vertex_code="jungle_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;"+vertex_code
  source=insert_vertex(source,vertex_code)
  var shader:=Shader.new();shader.code=source;shaders[path]=shader
 var result:ShaderMaterial=original.duplicate();result.shader=shaders[path];result.set_meta("headlight_probe",true);result.set_meta("family",family)
 converted[original.get_instance_id()]=result;materials.append(result);return result
func patch(node:Node)->void:
 if node is MeshInstance3D:
  if node.material_override:node.material_override=material(node.material_override)
  for surface in node.mesh.get_surface_count() if node.mesh else 0:
   if node.get_surface_override_material(surface):node.set_surface_override_material(surface,material(node.get_surface_override_material(surface)))
  if not node.material_override and node.mesh:patch_mesh(node.mesh)
 elif node is MultiMeshInstance3D and node.multimesh:patch_mesh(node.multimesh.mesh)
 for child in node.get_children():patch(child)
func patch_mesh(mesh:Mesh)->void:
 if not mesh:return
 for index in mesh.get_surface_count():
  var original:=mesh.surface_get_material(index)
  if original:mesh.surface_set_material(index,material(original))
func set_mode(mode:String)->void:
 for receiver in materials:
  receiver.set_shader_parameter("headlights_on",mode!="off")
  receiver.set_shader_parameter("headlights_per_pixel",mode=="mixed" and receiver.get_meta("family")!="terrain")
 for lens in lenses:lens.visible=mode!="off"
func position_vehicle(position:Vector3,pairs:int=1)->void:
 vehicle.global_position=position
 var positions:=PackedVector4Array();var axes:=PackedVector4Array()
 for pair in pairs:
  for side in [-1,1]:
   var p:Vector3=position+Vector3([0.,-4.,4.,8.][pair]+side*1.2,1.15,-4.02)
   positions.append(Vector4(p.x,p.y,p.z,60.))
   var direction:=Vector3(-side*.025,-.025,-1).normalized();axes.append(Vector4(direction.x,direction.y,direction.z,6.))
 positions.resize(8);axes.resize(8)
 for receiver in materials:
  receiver.set_shader_parameter("headlight_count",pairs*2)
  receiver.set_shader_parameter("headlight_positions",positions);receiver.set_shader_parameter("headlight_axes",axes)
func tick()->void:
 var start:=Time.get_ticks_usec()
 if not frozen:map.update_view(camera)
 var view_us:int=Time.get_ticks_usec()-start
 await process_frame;await RenderingServer.frame_post_draw
 var now:=Time.get_ticks_usec()
 if not sample_label.is_empty():frames.append({"label":sample_label,"wall_ms":(now-last_post)/1000.,"view_us":view_us,"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),"setup_cpu_ms":RenderingServer.get_frame_setup_time_cpu(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
 last_post=now
func warm(count:int)->void:
 sample_label=""
 for i in count:await tick()
func capture(name:String)->void:
 root.get_texture().get_image().save_png(OUTPUT+"/"+name+".png")
func run()->void:
 assert(DisplayServer.get_name()!="headless")
 DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1280,720);Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 world=Node3D.new();root.add_child(world)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.02,.03,.05);world.add_child(environment)
 map=Map.new();world.add_child(map);map.build(true,false);map.lighting.phase_override=0.;map.lighting.apply()
 vehicle=load("res://deathmatch/models/ground_transport/transport.glb").instantiate();world.add_child(vehicle);Transport.prepare_windows(vehicle);Transport.prepare_seats(vehicle);map.lighting.convert_node(vehicle)
 var lens_material:=StandardMaterial3D.new();lens_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;lens_material.albedo_color=Color(1.,.94,.8)
 for side in [-1,1]:
  var lens:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.22,.15,.08);box.material=lens_material;lens.mesh=box;lens.position=Vector3(side*1.2,1.15,-4.02);lens.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;vehicle.add_child(lens);lenses.append(lens)
 var library=preload("res://deathmatch/avatars/library.gd").new();world.add_child(library)
 avatar=library.create_avatar("20016c75fa136a32fd180fec93b3c7274f8ae2c851560691a0bc3b8a39e916f2");assert(avatar!=null,"Bundled avatar must load")
 world.add_child(avatar);avatar.rotation.y=PI;avatar.set_process(false)
 for i in 6:await process_frame
 avatar.process_mode=Node.PROCESS_MODE_DISABLED;avatar.hide()
 patch(map);patch(vehicle);patch(avatar)
 camera=Camera3D.new();camera.near=.05;camera.far=1000;camera.fov=65;world.add_child(camera);camera.make_current()
 var cases:Array=[{"name":"factory","vehicle":Map.Landscape.CENTERS[1]+Vector3(24,.12,8),"eye":Vector3(20,7,3),"aim":Vector3(0,2,-20)}, {"name":"driver","vehicle":Map.Landscape.CENTERS[1]+Vector3(24,.12,8),"eye":Transport.point(6,"seat")+Vector3.UP*1.48,"aim":Vector3(0,1.7,-28)}, {"name":"road","vehicle":Map.Landscape.CENTERS[3]+Vector3(0,.12,8),"eye":Vector3(8,4,9),"aim":Vector3(0,0,-35)}]
 var stress:bool=OS.get_cmdline_user_args().has("--stress")
 if stress:cases=[{"name":"driver8","vehicle":Map.Landscape.CENTERS[1]+Vector3(24,.12,8),"eye":Transport.point(6,"seat")+Vector3.UP*1.48,"aim":Vector3(0,1.7,-28),"pairs":4}]
 for view in cases:
  avatar.hide()
  avatar.global_position=view.vehicle+Vector3(0,0,-9)
  frozen=false;map.process_mode=Node.PROCESS_MODE_INHERIT
  position_vehicle(view.vehicle,view.get("pairs",1));camera.global_position=view.vehicle+view.eye;camera.look_at(view.vehicle+view.aim)
  set_mode("mixed");await warm(120)
  var deadline:int=Time.get_ticks_msec()+15000
  while not map.terrain.settled() and Time.get_ticks_msec()<deadline:await tick()
  await warm(120)
  # Freeze culling/LOD/residency and lighting updates to isolate receiver shading.
  frozen=true;map.process_mode=Node.PROCESS_MODE_DISABLED
  var variants:Array=[{"name":view.name,"pairs":view.get("pairs",1)}]
  if view.name=="driver" and not stress:
   variants.append({"name":"driver_player","pairs":1,"player":true})
   variants.append({"name":"driver8","pairs":4})
   variants.append({"name":"driver8_player","pairs":4,"player":true})
  for variant in variants:
   avatar.visible=variant.get("player",false)
   position_vehicle(view.vehicle,variant.pairs)
   for repeat in 2:
    var modes:Array=["off","vertex","mixed"] if repeat==0 else ["mixed","vertex","off"]
    for mode in modes:
     set_mode(mode);await warm(60);sample_label=variant.name+":"+mode+":"+str(repeat)
     for i in 120:await tick()
     sample_label=""
     if repeat==0:capture(variant.name+"-"+mode)
     print("HEADLIGHT_RENDER_CASE ",variant.name," ",mode," ",repeat)
 var report:Dictionary={"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1280,720],"frames":frames,"cases":cases,"materials":materials.size(),"shader_families":shaders.keys(),"range_m":60,"cone_half_angle_degrees":[12,24],"lights":2,"scope":"Render-only full map, night, one stationary transport, two unshadowed normal-free analytic cones. Vertex: all supported receivers; mixed: terrain vertex, supported other receivers per-pixel. No controller/network implementation, physics, GPU normals or shadow maps. Repeated order reverses. N95 GPU, not i7 target."}
 report.scope+=" Scene updates/LOD/residency frozen after settling for each viewpoint, isolating rendering. Driver8 reuses the exact driver scene with four lamp pairs but no additional vehicle meshes. Mixed receivers skip redundant vertex cone evaluation."
 report.lights_by_case={"factory":2,"driver":2,"road":2,"driver8":8,"driver_player":2,"driver8_player":8}
 report.avatar="Reference fragment-baked shader held constant; optimised vertex-baked shader measured separately. Bundled UT99 Malcolm soldier, 595 triangles, frozen pose, weapons hidden, 9m ahead of vehicle origin. Driver player variants reuse the exact frozen baseline scene. Original skin atlas and GPU vertex animation/IK shader preserved; cone term added after vertex displacement."
 if stress:
  report.lights=8;report.scope+=" Eight-cone stress adds three lamp pairs without additional vehicle meshes, isolating receiver lighting cost."
 FileAccess.open(OUTPUT+("/stress-results.json" if stress else "/results.json"),FileAccess.WRITE).store_string(JSON.stringify(report))
 world.free();await process_frame;print("HEADLIGHT_COMPARISON_SAVED ",OUTPUT);quit()
