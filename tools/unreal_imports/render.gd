extends SceneTree
var g
var camera: Camera3D
var render_view: SubViewport
var folder: String
var captures: Array=[]
func _initialize():run.call_deferred()
func v(a):return Vector3(a[0],a[1],a[2])
func values(p: Vector3):return [p.x,p.y,p.z]
func capture(name: String,eye: Vector3,target: Vector3,overview: bool=false,size: float=0.):
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL if overview else Camera3D.PROJECTION_PERSPECTIVE
 camera.size=maxf(size,1.);camera.fov=78;camera.far=12000;camera.near=.08
 camera.global_position=eye;camera.look_at(target,Vector3.FORWARD if absf((target-eye).normalized().y)>.99 else Vector3.UP)
 var env: Environment=g.get_node("Environment").environment
 var fog:=env.fog_enabled;var volume:=env.volumetric_fog_enabled
 for weather in g.find_children("*","Node3D",true,false):
  if weather.get_script()!=preload("res://deathmatch/maps/weather.gd"):continue
  weather.set_physics_process(false);weather.visible=not overview
  if not overview:
   weather.global_position=eye;weather.material.set_shader_parameter("focus",eye);weather.update_roofs(eye)
 if overview:env.fog_enabled=false;env.volumetric_fog_enabled=false
 for frame in 2:await process_frame
 await RenderingServer.frame_post_draw
 var picture:=render_view.get_texture().get_image();assert(picture.save_png(folder+"/"+name+".png")==OK)
 captures.append({"name":name,"eye":values(eye),"target":values(target),"orthographic":overview,"fog_disabled_for_overview":overview,"width":picture.get_width(),"height":picture.get_height()})
 env.fog_enabled=fog;env.volumetric_fog_enabled=volume
 print("MAP_RENDER ",name)
func run():
 var path: String=OS.get_cmdline_user_args()[0];var key=path.get_file().get_basename()
 var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path.get_base_dir()+"/render-plan.json"))
 folder=("res://test-results/as-gallery/" if plan.mode=="as" else "res://test-results/koth-gallery/")+key;DirAccess.make_dir_recursive_absolute(folder)
 root.size=Vector2i(960,540);root.content_scale_size=root.size
 g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
 g.map_catalog.append({"id":key,"title":key,"path":path,"scene":path.get_basename()+".scn","sha256":FileAccess.get_sha256(path),"modes":[plan.mode]});g.selected_map=key
 g.start_host("Map gallery",0,100,15,true,plan.mode,"quake")
 if g.current_map!=key:push_error("Wrong map loaded");quit(1);return
 if plan.mode=="as":g.match_mode.draw_objectives()
 g.set_process(false);g.set_physics_process(false);g.menu_open=false;g.hud.hide()
 for id in g.players:g.players[id].spectator=true;g.fighters[id].hide()
 if g.has_node("Menu"):g.get_node("Menu").hide()
 render_view=SubViewport.new();render_view.size=Vector2i(1920,1080);render_view.world_3d=g.get_world_3d();render_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;render_view.msaa_3d=Viewport.MSAA_4X;root.add_child(render_view)
 camera=Camera3D.new();render_view.add_child(camera);camera.make_current();root.disable_3d=true
 await physics_frame;await physics_frame
 var lo: Vector3=v(plan.min);var hi: Vector3=v(plan.max);var center: Vector3=(lo+hi)*.5
 var span: Vector3=hi-lo;var extent: float=maxf(span.x,span.z)
 var frame_size: float=maxf(span.z,span.x/(1920./1080.))*1.15
 await capture("01-top-overview",center+Vector3.UP*(extent+span.y+50),center,true,frame_size)
 var diagonal_size: float=maxf(extent*.82,span.y+extent*.45)*1.15
 await capture("02-full-overview",center+Vector3(1.,1.15,1.)*(extent+30),center,true,diagonal_size)
 await capture("03-reverse-overview",center+Vector3(-1.,1.15,-1.)*(extent+30),center,true,diagonal_size)
 for row in plan.views:
  var eye: Vector3=v(row.eye);var target: Vector3=v(row.target)
  if plan.mode=="as" and "objective" in row.name:
   target=eye-Vector3.UP*.4
   var best:=0.0
   for index in 16:
    var angle:=TAU*index/16.0
    var desired:=target+Vector3(cos(angle)*3,.8,sin(angle)*3)
    var hit=g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(target,desired,1))
    var candidate: Vector3=desired if hit.is_empty() else target.lerp(hit.position,.8)
    if candidate.distance_to(target)>best:best=candidate.distance_to(target);eye=candidate
  await capture(row.name,eye,target)
 FileAccess.open(folder+"/renders.json",FileAccess.WRITE).store_string(JSON.stringify({"id":key,"mode":plan.mode,"renderer":RenderingServer.get_current_rendering_method(),"bsp_sha256":FileAccess.get_sha256(path),"captures":captures},"  "))
 g.disconnect_game("Render complete");render_view.queue_free();g.queue_free()
 for frame in 4:await process_frame
 print("MAP_GALLERY_DONE ",key);quit()
