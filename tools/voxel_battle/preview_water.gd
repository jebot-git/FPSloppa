extends SceneTree
## Capture all six authored landmarks in the actual streamed jungle renderer.
const Preview=preload("res://tools/voxel_battle/jungle_preview.gd")
var scene
var ready:=false
var output:="res://test-results/rivers/render"
func _initialize() -> void:run.call_deferred()
func _process(_delta:float) -> bool:
 if ready:scene.map.update_view(scene.camera)
 return false
func run() -> void:
 if DisplayServer.get_name()=="headless":push_error("Vulkan rendering required");quit(1);return
 var args:=OS.get_cmdline_user_args()
 if args.has("--output"):output=args[args.find("--output")+1]
 DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1440,900)
 scene=load("res://tools/voxel_battle/jungle_preview.tscn").instantiate();scene.benchmarks=true;root.add_child(scene);scene.panel.visible=false;scene.map.structures.force_near=true;ready=true
 var title:=Label.new();title.position=Vector2(24,22);title.add_theme_font_size_override("font_size",26);root.add_child(title)
 var records:Array=[]
 for i in 4:
  var center:Vector3=[Vector3(-470,21,0),Vector3(350,49,-739),Vector3(750,49,1170),Vector3(-650,0,1020)][i]
  var eye:=center+Vector3(-15,160,-20)
  eye.y=maxf(eye.y,scene.Landscape.surface(eye.x,eye.z).x+60)
  scene.camera.position=eye;scene.camera.fov=58;scene.camera.look_at(center+Vector3(0,5,0))
  title.text=["WESTERN CANYON RIVER","NORTHERN GORGE RIVER","EXPEDITION RIVER","PORT ESTUARY"][i]+" · JUNGLE FRONTIER"
  var start:=Time.get_ticks_msec();await process_frame
  while not scene.map.terrain.settled():
   await process_frame
   if Time.get_ticks_msec()-start>90000:push_error("Terrain stream timeout");quit(1);return
  await create_timer(1.0).timeout
  await RenderingServer.frame_post_draw
  var name:String=["western-canyon","northern-gorge","expedition","port-estuary"][i]
  root.get_texture().get_image().save_png(output+"/"+name+".png")
  var counts:Array=[]
  for mesh in scene.map.structures.meshes[i]:counts.append(mesh.surface_get_array_index_len(0)/3)
  records.append({"name":name,"water_triangles":scene.map.waterways.triangles,"bridge_sections":scene.map.waterways.bridges.size(),"triangles_by_lod":counts,"visible_structure_sites":scene.map.structures.visible_sites,"terrain_resident":scene.map.terrain.resident.size()})
  print("Captured ",name)
 var report:={"sites":records,"renderer":RenderingServer.get_current_rendering_method(),"hardware":RenderingServer.get_video_adapter_name(),"resolution":[1440,900],"scope":"Settled oblique overview captures of authored river channels, water surfaces and road bridges in the full streamed terrain, hybrid forest and undergrowth renderer. No physics, AI or avatars; no performance claim from captures."}
 FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 scene.map.terrain.shutdown();quit()
