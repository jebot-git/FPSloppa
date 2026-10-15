extends SceneTree
const OUTPUT:="res://test-results/foliage-lighting/world"
var scene
var running:=false
func _initialize()->void:run.call_deferred()
func _process(_delta:float)->bool:
 if running:scene.map.update_view(scene.camera)
 return false
func capture(name:String)->void:
 await create_timer(.3).timeout;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUTPUT+"/"+name+".png")
func run()->void:
 DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
 scene=load("res://tools/voxel_battle/jungle_preview.tscn").instantiate();scene.benchmarks=true;root.add_child(scene);scene.panel.visible=false
 scene.set_view(0);scene.camera.position.y+=100;scene.camera.look_at(scene.camera.position+Vector3(.8,-.35,-1));running=true
 var begin:=Time.get_ticks_msec()
 while not scene.map.terrain.settled():
  await process_frame
  assert(Time.get_ticks_msec()-begin<90000)
 var originals:Array=[]
 for kind in 3:
  for lod in 3:
   var mesh:Mesh=scene.map.environment.variants.billboard[kind][lod]
   assert(mesh.surface_get_material(0) is ShaderMaterial)
   originals.append([mesh,mesh.surface_get_material(0)])
   var raw:Mesh=scene.map.environment.card(kind) if kind<2 else scene.map.environment.Under.card(2)
   mesh.surface_set_material(0,raw.surface_get_material(0))
 scene.map.lighting.phase_override=0.;await capture("before-night")
 for row in originals:row[0].surface_set_material(0,row[1])
 await capture("night")
 scene.map.lighting.phase_override=1.;await capture("day")
 scene.map.lighting.weather_cloud=1.;await capture("storm")
 scene.map.lighting.weather_flash=1.;await capture("lightning")
 running=false;scene.map.terrain.shutdown();scene.free();scene=null;await process_frame;await create_timer(.3).timeout
 print("CQ_FOLIAGE_WORLD_PASS");quit()
