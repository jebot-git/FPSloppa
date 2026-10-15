extends SceneTree
## Real foliage assets and GPU materials: catch full-bright cutout LOD regressions.
const Lighting=preload("res://tools/voxel_battle/baked_lighting.gd")
const Scenery=preload("res://tools/voxel_battle/environment.gd")
const Under=preload("res://tools/voxel_battle/undergrowth_assets.gd")
const OUTPUT:="res://test-results/foliage-lighting"
var checks:=0
var failures:Array[String]=[]
var stage:Node3D
var camera:Camera3D
var cards:Array=[]
var regions:Array[Rect2i]=[]
var metrics:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func illumination(kind:String)->void:
 RenderingServer.global_shader_parameter_set("jungle_day_mix",0. if kind=="night" else 1.)
 RenderingServer.global_shader_parameter_set("jungle_sun_mix",Vector3.ZERO if kind=="night" else Vector3(1,0,0))
 RenderingServer.global_shader_parameter_set("jungle_sky_color",Vector3(.001,.002,.004) if kind=="night" else Vector3(.15,.3,.5))
 RenderingServer.global_shader_parameter_set("jungle_weather",Vector3(1,1 if kind=="lightning" else 0,0) if kind in ["storm","lightning"] else Vector3.ZERO)
func capture(name:String,kind:String)->Array:
 illumination(kind)
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image();image.save_png(OUTPUT+"/"+name+".png")
 var sums:Array=[]
 for rect in regions:
  var sum:=0.
  if rect.get_area()==0:sums.append(0.);continue
  for y in range(rect.position.y,rect.end.y):
   for x in range(rect.position.x,rect.end.x):
    var color:=image.get_pixel(x,y);sum+=color.r*.2126+color.g*.7152+color.b*.0722
  sums.append(sum/rect.get_area())
 metrics[name]=sums;return sums
func instance(mesh:Mesh,point:Vector3,scale_value:float)->void:
 var node:=MultiMeshInstance3D.new();node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.mesh=mesh;node.multimesh.instance_count=1
 # Translation and instance scale exercise the same shader path used by live foliage.
 node.multimesh.set_instance_transform(0,Transform3D(Basis(Vector3.UP,.65).scaled(Vector3.ONE*scale_value),point));stage.add_child(node)
func run()->void:
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 var foliage:=Scenery.new();foliage.make_variants()
 for kind in 3:
  for lod in 3:
   var mesh:Mesh=foliage.variants.billboard[kind][lod];Lighting.convert_mesh(mesh)
   check(mesh.surface_get_material(0) is ShaderMaterial,"All tree/bush billboard variants use baked lighting")
 for kind in 4:
  var mesh:=Under.card(kind);Lighting.convert_mesh(mesh)
  check(mesh.surface_get_material(0) is ShaderMaterial,"All far undergrowth species use baked lighting")
 var custom:=StandardMaterial3D.new();custom.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y;custom.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;custom.albedo_color=Color(.4,.7,.2,.8);custom.alpha_scissor_threshold=.67
 var converted:=Lighting.surface(custom) as ShaderMaterial
 check(converted!=null and converted.get_shader_parameter("tint")==custom.albedo_color,"Cutout conversion preserves tint/alpha")
 check(is_equal_approx(converted.get_shader_parameter("alpha_cutoff"),.67),"Cutout conversion preserves threshold")
 var blended:=StandardMaterial3D.new();blended.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y;blended.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 check(Lighting.surface(blended)==blended,"Blended effects stay on their own materials")
 foliage.free()
 if DisplayServer.get_name()=="headless":finish();return
 root.size=Vector2i(960,600);root.content_scale_size=Vector2i(960,600);stage=Node3D.new();root.add_child(stage)
 var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color.BLACK;world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED;stage.add_child(world)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=48;camera.position=Vector3(0,13,60);stage.add_child(camera);camera.look_at(Vector3(0,10,0));camera.current=true
 var atlas:=Image.create(16,16,false,Image.FORMAT_RGBAF);atlas.fill(Color(.8,0,.5,.8))
 RenderingServer.global_shader_parameter_set("jungle_baked_enabled",true);RenderingServer.global_shader_parameter_set("jungle_extent",128.)
 RenderingServer.global_shader_parameter_set("jungle_light_atlas",ImageTexture.create_from_image(atlas));RenderingServer.global_shader_parameter_set("jungle_dawn_atlas",ImageTexture.create_from_image(atlas))
 var tree:=Scenery.asset(0,0);Lighting.convert_mesh(tree);var bush:=Under.asset(2,0);Lighting.convert_mesh(bush)
 cards=[Scenery.card(0),Under.card(2)]
 var positions:=[Vector3(-24,0,0),Vector3(-8,0,0),Vector3(10,0,0),Vector3(26,0,0)]
 for index in 4:instance([tree,cards[0],bush,cards[1]][index],positions[index],1. if index<2 else 4.)
 await process_frame
 for point in positions:
  var x:=roundi(camera.unproject_position(point+Vector3.UP*10).x)
  var rect:=Rect2i(x-95,10,190,580)
  check(Rect2i(0,0,960,600).encloses(rect),"Capture regions lie inside the viewport")
  regions.append(rect.intersection(Rect2i(0,0,960,600)))
 var before:=await capture("before-night","night")
 for card in cards:Lighting.convert_mesh(card)
 var night:=await capture("night","night")
 var day:=await capture("day","day")
 var storm:=await capture("storm","storm")
 var flash:=await capture("lightning","lightning")
 for index in [1,3]:
  check(night[index]<before[index]*.03,"Converted billboard loses full-bright night appearance")
  check(night[index]<day[index]*.03,"Billboard follows world night exposure")
  check(storm[index]<day[index]*.85,"Billboard darkens under storm clouds")
  check(flash[index]>storm[index]*1.1,"Billboard responds to lightning")
  var near:int=index-1
  check(absf(storm[index]/day[index]-storm[near]/day[near])<.08,"Billboard/mesh have matching relative storm response")
 # Check atlas attenuation, then verify the lookup uses each instance position.
 atlas.fill(Color(.15,0,.1,.15));RenderingServer.global_shader_parameter_set("jungle_light_atlas",ImageTexture.create_from_image(atlas))
 var shade:=await capture("shade","day")
 for index in [1,3]:check(shade[index]<day[index]*.7,"Billboard samples local baked irradiance")
 for y in atlas.get_height():
  for x in atlas.get_width():atlas.set_pixel(x,y,Color(.15,0,.1,.15) if x<8 else Color(.8,0,.5,.8))
 RenderingServer.global_shader_parameter_set("jungle_light_atlas",ImageTexture.create_from_image(atlas))
 var local_shade:=await capture("local-shade","day")
 check(local_shade[1]<day[1]*.7,"Card instance in shadow uses its local atlas region")
 check(local_shade[3]>day[3]*.95,"Card instance in daylight does not inherit another instance's shadow")
 stage.free();stage=null;Lighting.converted.clear()
 RenderingServer.global_shader_parameter_set("jungle_baked_enabled",false);RenderingServer.global_shader_parameter_set("jungle_weather",Vector3.ZERO)
 await process_frame;await create_timer(.3).timeout;finish()
func finish()->void:
 var result:Dictionary={"checks":checks,"failures":failures,"column_order":["tree_mesh","tree_card","bush_mesh","bush_card"],"luminance":metrics}
 FileAccess.open(OUTPUT+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print("CQ_FOLIAGE_LIGHTING ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
