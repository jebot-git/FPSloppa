extends SceneTree
var stage: Node3D
var camera: Camera3D
var render_view: SubViewport
var output:="res://test-results/t2-vehicles/textured"
func _initialize():run.call_deferred()
func shot(name: String,eye: Vector3,target: Vector3,size: float):
 camera.position=eye;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=size
 camera.look_at(target,Vector3.FORWARD if absf((target-eye).normalized().y)>.99 else Vector3.UP)
 for frame in 8:await process_frame
 await RenderingServer.frame_post_draw
 assert(render_view.get_texture().get_image().save_png(output+"/"+name+".png")==OK)
func run():
 root.size=Vector2i(960,600);root.content_scale_size=root.size
 render_view=SubViewport.new();render_view.size=Vector2i(1600,1000);render_view.own_world_3d=true;render_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;render_view.msaa_3d=Viewport.MSAA_4X;root.add_child(render_view)
 DirAccess.make_dir_recursive_absolute(output)
 stage=Node3D.new();render_view.add_child(stage)
 var world:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("182b36");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("bdccd6");env.ambient_light_energy=.65;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;world.environment=env;stage.add_child(world)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0);sun.light_energy=1.5;stage.add_child(sun)
 camera=Camera3D.new();stage.add_child(camera);camera.make_current()
 var audit: Array=[]
 for kind in ["wildcat","shrike","havoc","beowulf","thundersword","jericho"]:
  var model: Node3D=load("res://deathmatch/vehicles/tribes/"+kind+".scn").instantiate();stage.add_child(model)
  var bounds:=AABB();var first:=true;var faces:=0;var materials:=0;var textured:=0
  for mesh in model.find_children("*","MeshInstance3D",true,false):
   bounds=mesh.get_aabb() if first else bounds.merge(mesh.get_aabb());first=false
   for surface in mesh.mesh.get_surface_count():
    materials+=1;var mat: StandardMaterial3D=mesh.mesh.surface_get_material(surface)
    var arrays: Array=mesh.mesh.surface_get_arrays(surface);faces+=arrays[Mesh.ARRAY_INDEX].size()/3
    if mat.albedo_texture:
     textured+=1;assert(mat.albedo_texture.get_image().has_mipmaps())
     var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
     for uv in uvs:assert(uv.is_finite() and uv.x>=0 and uv.x<=1 and uv.y>=0 and uv.y<=1)
  assert(materials==5 and textured==4)
  var center:=bounds.get_center();var length: float=maxf(bounds.size.x,bounds.size.z);var size:=length*.9
  await shot(kind+"-front",center+Vector3(1.,.7,-1.)*length,center,size)
  await shot(kind+"-rear",center+Vector3(-1.,.7,1.)*length,center,size)
  await shot(kind+"-side",center+Vector3(1.,.18,0)*length,center,length*.75)
  await shot(kind+"-top",center+Vector3.UP*length*2,center,length*1.08)
  var cockpit: Vector3=preload("res://deathmatch/vehicles/tribes/scout_data.gd").definition(kind).seats[0]
  await shot(kind+"-cockpit",cockpit+Vector3(2.,2.2,-2.),cockpit+Vector3(0,.3,-.25),2.6)
  for mesh in model.find_children("*","MeshInstance3D",true,false):
   for surface in mesh.mesh.get_surface_count():
    var mat=mesh.get_active_material(surface)
    if "TeamPanel" in mat.resource_name:
     mat=mat.duplicate();mat.albedo_color=Color("306b9d");mesh.set_surface_override_material(surface,mat)
  await shot(kind+"-blue",center+Vector3(1.,.7,-1.)*length,center,size)
  audit.append({"kind":kind,"surfaces":materials,"textured_surfaces":textured,"triangles":faces,"mipmaps":true,"normalized_uvs":true,"scene_sha256":FileAccess.get_sha256("res://deathmatch/vehicles/tribes/"+kind+".scn")})
  model.free()
 FileAccess.open(output+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify(audit,"  "))
 print("T2_TEXTURED_PREVIEW_PASS ",JSON.stringify(audit));quit()
