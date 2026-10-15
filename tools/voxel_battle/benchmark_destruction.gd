extends SceneTree
const Map=preload("res://tools/voxel_battle/map.gd")
const Destruction=preload("res://tools/voxel_battle/destruction.gd")
class Game extends Node3D:
 var active:=true
 var map_epoch:=1
 var resident=null
var game
var map
var camera:Camera3D
var out:="res://test-results/destruction"
func _initialize()->void:run.call_deferred()
func sample(count:int)->Dictionary:
 var timings:Array=[]
 for i in count:
  var start:=Time.get_ticks_usec()
  map.update_view(camera)
  await process_frame;await RenderingServer.frame_post_draw
  timings.append((Time.get_ticks_usec()-start)/1000.)
 timings.sort()
 var total:=0.
 for value in timings:total+=value
 return {"mean_ms":total/count,"p95_ms":timings[int(count*.95)],"max_ms":timings[-1],"frames":count,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
func capture(name:String)->void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
func run()->void:
 var structural:bool=OS.get_cmdline_user_args().has("--structural-collapse")
 if structural:out="res://test-results/structural-collapse"
 DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1280,720)
 game=Game.new();root.add_child(game)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.38,.55,.63);game.add_child(environment)
 var draw:bool=DisplayServer.get_name()!="headless"
 map=Map.new();game.add_child(map);map.build(draw,true);map.lighting.phase_override=1.
 var service:=Destruction.new();game.add_child(service);service.setup(game,map,draw,true)
 camera=Camera3D.new();camera.far=1200;game.add_child(camera);camera.make_current()
 var target:Dictionary={}
 for c in service.cells:
  if c.kind==1 and c.size.z<.3 and c.size.y>3. and c.center.y<3.:
   target=c;break
 assert(not target.is_empty())
 var building_id:int=service.integrity.wall_building[target.wall]
 var building:Dictionary=service.integrity.buildings[building_id]
 if not draw:
  await physics_frame;await physics_frame
  var first:=Time.get_ticks_usec();service.impact(target.position+Vector3(0,0,.13),120,5);var first_us:=Time.get_ticks_usec()-first
  var start:=Time.get_ticks_usec()
  for i in 12:service.impact(target.position+Vector3((i%4-1.5)*4,0,(i/4-1)*4),300,35)
  var report:Dictionary={"first_impact_us":first_us,"twelve_impacts_us":Time.get_ticks_usec()-start,"broken":service.broken.size(),"cells":service.cells.size(),"graphics":false}
  if structural:
   var collapse_start:=Time.get_ticks_usec();fail_storey(service,building_id,1)
   report.collapse_us=Time.get_ticks_usec()-collapse_start;report.collapse_detail=service.last_collapse_stats;report.collapsed=service.collapsed.keys();report.integrity=service.integrity.status(building_id,service.broken)
  FileAccess.open(out+"/server-results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("DESTRUCTION_SERVER_BENCHMARK ",JSON.stringify(report))
  game.queue_free();await process_frame;quit();return
 var normal:=Vector3(0,0,1 if target.center.z>0 else -1)
 camera.position=target.position+normal*12+Vector3(1,1.5,0);camera.look_at(target.position)
 if structural:
  var center:Vector3=Map.Landscape.CENTERS[building.kind]+building.center
  camera.position=center+Vector3(building.size.x*1.2,building.floors*3.6*.5+8,building.size.y*1.4+20)
  camera.look_at(center+Vector3.UP*building.floors*3.6*.4)
 for i in 60:map.update_view(camera);await process_frame
 var intact:=await sample(90);await capture("intact")
 var start:=Time.get_ticks_usec();service.impact(target.position+normal*.13,120,5);var collision_us:=Time.get_ticks_usec()-start
 start=Time.get_ticks_usec();service.flush_meshes();var mesh_us:=Time.get_ticks_usec()-start
 var breakup:=await sample(15);await capture("breakup")
 for i in 90:map.update_view(camera);await process_frame
 var breached:=await sample(90);await capture("breached")
 var bombard_start:=Time.get_ticks_usec()
 for i in 12:service.impact(target.position+Vector3((i%4-1.5)*4,0,(i/4-1)*4),300,35)
 var bombard_collision_us:=Time.get_ticks_usec()-bombard_start
 service.flush_meshes();var bombard_mesh_us:=service.rebuild_usec
 var bombardment:=await sample(30)
 var report:Dictionary={"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1280,720],"intact":intact,"first_impact_collision_us":collision_us,"first_impact_mesh_us":mesh_us,"breakup":breakup,"breached":breached,"bombardment":bombardment,"bombardment_collision_us":bombard_collision_us,"bombardment_mesh_us":bombard_mesh_us,"broken":service.broken.size(),"catalog_cells":service.cells.size(),"catalog_walls":service.walls.size(),"shard_limit":service.MAX_SHARDS,"scope":"Full streamed map, real colliders, one factory breach then twelve coalesced impacts. No players/AI; desktop GPU only, not a 64-player or VR performance claim."}
 if structural:
  start=Time.get_ticks_usec();fail_storey(service,building_id,1);report.collapse_collision_animation_us=Time.get_ticks_usec()-start;report.collapse_detail=service.last_collapse_stats
  service.flush_meshes();report.collapse_mesh_us=service.rebuild_usec
  await create_timer(.7).timeout;await capture("collapse")
  await create_timer(1.).timeout
  report.after_collapse=await sample(60);report.collapsed=service.collapsed.keys();report.buildings=service.integrity.buildings.size();report.integrity=service.integrity.status(building_id,service.broken)
  await capture("collapsed")
 FileAccess.open(out+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("DESTRUCTION_BENCHMARK ",JSON.stringify(report))
 game.queue_free();await process_frame;quit()

func fail_storey(service,id:int,floor_index:int)->void:
 var ids:=PackedInt32Array()
 for column in service.integrity.buildings[id].stories[floor_index]:
  for cell in column.cells:
   if not cell in ids:ids.append(cell)
 service.apply_breaks(ids,Map.Landscape.CENTERS[service.integrity.buildings[id].kind]+service.integrity.buildings[id].center,true)
