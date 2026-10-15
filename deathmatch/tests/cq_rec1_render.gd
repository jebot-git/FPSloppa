extends SceneTree
const Lighting=preload("res://tools/voxel_battle/baked_lighting.gd")
const Models=preload("res://deathmatch/conquest/classes/models.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func capture(viewport:SubViewport,name:String)->Image:
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 var img:=viewport.get_texture().get_image();img.save_png("/home/blux/.cache/cq-rec1-review/render/"+name+".png");return img
func bright(img:Image)->int:
 var count:=0
 for y in range(80,400,2):
  for x in range(100,540,2):
   var c:=img.get_pixel(x,y)
   if maxf(c.r,maxf(c.g,c.b))>.12:count+=1
 return count
func run():
 DirAccess.make_dir_recursive_absolute("/home/blux/.cache/cq-rec1-review/render")
 var viewport:=SubViewport.new();viewport.size=Vector2i(640,480);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var stage:=Node3D.new();viewport.add_child(stage)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.001,.001,.001);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED;stage.add_child(env)
 var camera:=Camera3D.new();camera.near=.01;camera.fov=55;camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;stage.add_child(camera)
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Lighting.ROOT+"bake.json"));var point:Array=data.lamps[0].position
 var at:=Vector3(point[0],point[1]-1.2,point[2]);camera.position=at+Vector3(0,.03,.65);camera.look_at(at)
 RenderingServer.global_shader_parameter_set("jungle_extent",2828.42712474619)
 RenderingServer.global_shader_parameter_set("jungle_light_atlas",load(Lighting.ROOT+"irradiance.png"));RenderingServer.global_shader_parameter_set("jungle_dawn_atlas",load(Lighting.ROOT+"dawn.png"));RenderingServer.global_shader_parameter_set("jungle_baked_enabled",true)
 RenderingServer.global_shader_parameter_set("jungle_day_mix",0.);RenderingServer.global_shader_parameter_set("jungle_sun_mix",Vector3.ZERO);RenderingServer.global_shader_parameter_set("jungle_sky_color",Vector3(.001,.001,.002))
 for name in ["hand","grenade"]:
  var model:Node3D=load("res://addons/godot-xr-tools/hands/scenes/lowpoly/left_tac_glove_low.tscn").instantiate() if name=="hand" else preload("res://deathmatch/conquest/classes/grenade_visuals.gd").model(0)
  Lighting.convert_node(model);stage.add_child(model);model.set_physics_process(false);model.global_position=at
  if name=="hand":model.rotation.x=PI/2
  var img:Image=await capture(viewport,name+"-night-light");check(bright(img)>80,"local "+name+" receives baked fixture illumination without dynamic scene lights")
  if name=="hand":
   var cloak=preload("res://deathmatch/vr/cq_cloak.gd").new();cloak.update(true,[model]);var cloaked:Image=await capture(viewport,"hand-cloaked");check(cloaked.get_data()!=img.get_data(),"player sees local cloak dissolve");cloak.update(false,[]);cloak=null
  model.free()
 var support=preload("res://deathmatch/vr/aim_support.gd").new()
 for w in [0,1,2,3,4,9,10]:
  support.reset();var primary:=Transform3D(Basis.IDENTITY,Vector3(0,1.1,-.3));var hand:=Transform3D(Basis.IDENTITY,primary*Models.anchor(w,"support_anchor")*.65)
  # Offset is model-relative; do not scale the tracked primary position.
  hand.origin=primary* (Models.anchor(w,"support_anchor")*.65)
  support.solve(primary,hand,w,true,true,"cq");check(support.engaged,"support latch accepts weapon "+str(w))
  support.solve(primary,hand,w,false,true,"cq");check(not support.engaged,"support latch releases weapon "+str(w))
 var equipment=preload("res://deathmatch/avatars/equipment.gd").utility("recon");stage.add_child(equipment);equipment.position=at
 var cell:Image=await capture(viewport,"cloak-cell");check(bright(cell)>40,"optimized cloak cell remains legible at night")
 check(not equipment.has_meta("cq_weapon") and equipment.find_child("AlignedRedDot",true,false)==null,"cloak device is not a designator");equipment.free()
 var fixture=preload("res://tools/voxel_battle/light_fixtures.gd")
 var layout=preload("res://tools/voxel_battle/architecture.gd").new();layout.generate()
 for lamp in fixture.rows(layout.buildings):
  if lamp.type!="hanging":continue
  var supported:=false
  for box in layout.render_boxes:
   if box.kind==lamp.kind and box.lod==0 and is_equal_approx(box.size.y,.20) and AABB(box.center-box.size*.5,box.size).has_point(lamp.local+Vector3.UP*.45):supported=true;break
  check(supported,"ceiling lamp has an actual slab attachment "+str(lamp.local))
 viewport.queue_free();await process_frame;RenderingServer.global_shader_parameter_set("jungle_baked_enabled",false)
 print("CQ_REC1_RENDER_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
