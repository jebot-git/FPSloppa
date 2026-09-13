extends SceneTree
const Assets=preload("res://deathmatch/maps/surface_assets.gd")
const Motion=preload("res://deathmatch/maps/surface_motion.gd")
const Atmosphere=preload("res://deathmatch/maps/atmosphere.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const Preferences=preload("res://deathmatch/settings/preferences.gd")
class Game extends Node:
 var current_map:="tf_vesper"
 var presentation: Dictionary={}
var failures: Array=[]
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func texture(colour: Color,size: int=8) -> Texture2D:
 var img:=Image.create(size,size,false,Image.FORMAT_RGB8);img.fill(colour)
 return ImageTexture.create_from_image(img)
func item(name: String,size: int=8,glow: bool=false) -> Dictionary:
 var mat:=StandardMaterial3D.new();mat.albedo_texture=texture(Color.RED,size)
 if glow:mat.emission_texture=texture(Color.BLUE,size);mat.emission_enabled=true
 return {"source_name":name,"material":mat}
func run() -> void:
 var level:=Node3D.new()
 Assets.capture(level,[item("+0lamp"),item("+1lamp",8,true),item("+alamp"),item("+blamp"),item("+0gap"),item("+2gap"),item("+0size"),item("+1size",16)])
 var bank: Dictionary=level.get_meta(Assets.FRAME_TAG)
 check(bank.size()==2 and bank.has("0lamp") and bank.has("alamp"),"Contiguous frames and alternate cycles; gaps/wrong dimensions rejected")
 check(bank["0lamp"][1].glow!=null and bank["0lamp"][0].glow==null,"Optional per-frame glow preserved")
 var mat:=ShaderMaterial.new();mat.shader=Filtering.BAKED;mat.set_meta("bsp_texture_name","+0lamp")
 var base:=texture(Color.GREEN);mat.set_shader_parameter("base_texture",base)
 var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();mesh.material_override=mat;level.add_child(mesh)
 var water:=ShaderMaterial.new();water.shader=Filtering.BAKED;water.set_meta("bsp_texture_name","*water")
 water.set_shader_parameter("map_uv_offset",Vector2(.3,.2))
 var pool:=MeshInstance3D.new();pool.mesh=BoxMesh.new();pool.material_override=water;level.add_child(pool)
 var contents=load("res://deathmatch/maps/contents.gd").new();contents.open("res://maps/tf_vesper.bsp")
 check(contents.at(Vector3(18,2.2,24))==-2 and contents.at(Vector3(15,2.2,24))==-1,"Vesper camera regression: original inside wall, corrected corridor empty")
 var cached:=PackedScene.new();level.set_meta("bsp_source_sha256","fixture");cached.pack(level)
 check(not preload("res://deathmatch/maps/loader.gd").cache_matches(cached,"fixture"),"Caches without presentation data rejected")
 level.set_meta("map_presentation_version",Assets.VERSION);cached.pack(level)
 check(preload("res://deathmatch/maps/loader.gd").cache_matches(cached,"fixture") and not preload("res://deathmatch/maps/loader.gd").cache_matches(cached,"other"),"Cache requires current presentation version and source hash")
 var game:=Game.new();root.add_child(game)
 var environment:=WorldEnvironment.new();environment.name="Environment";environment.environment=Environment.new();game.add_child(environment)
 var original:=environment.environment;original.fog_enabled=false;original.ambient_light_energy=.6
 var motion:=Motion.new();game.add_child(motion);motion.configure(game,level);motion.set_process(false)
 motion.advance(.21)
 check(mat.get_shader_parameter("base_texture")==bank["0lamp"][1].base and mat.get_shader_parameter("glow_texture")==bank["0lamp"][1].glow,"5 Hz selection switches colour and glow together")
 for mode in 3:
  Filtering.new().apply(level,mode,false)
  check(mat.get_shader_parameter("base_nearest")==mat.get_shader_parameter("base_texture") and mat.get_shader_parameter("texture_filter_mode")==mode,"Animated frames survive filter mode "+str(mode))
 motion.apply({"surface_animation":false,"surface_variation":false,"map_atmosphere":false})
 check(mat.get_shader_parameter("base_texture")==base and not mat.get_shader_parameter("has_glow") and not water.get_shader_parameter("liquid_warp"),"Disabling animation restores authored initial texture and opaque liquid")
 check(water.get_shader_parameter("map_uv_offset")==Vector2(.3,.2),"Animation does not overwrite conveyor offset")
 check(environment.environment.sky.sky_material is PanoramaSkyMaterial and not environment.environment.fog_enabled,"Legacy disabled atmosphere preference cannot disable sky or enable fog")
 Atmosphere.apply(game,"tf_vesper")
 var abbey:=environment.environment
 check(abbey!=original and not abbey.fog_enabled and not abbey.volumetric_fog_enabled,"Abbey has no depth or volumetric fog")
 check(abbey.ambient_light_energy==original.ambient_light_energy,"Ambient lighting remains unchanged")
 Atmosphere.apply(game,"tf_pressureworks")
 check(environment.environment!=abbey,"Maps select distinct sky profiles")
 Atmosphere.apply(game,"tf_vesper")
 check(environment.environment==abbey,"Sky/profile resources reused across rotation")
 Atmosphere.apply(game,"external-random")
 check(environment.environment.ambient_light_energy==original.ambient_light_energy and not environment.environment.fog_enabled,"Unknown BSP preserves lighting with fog disabled")
 Atmosphere.apply(game,"tf_vesper");Atmosphere.apply(game,"__waiting_lobby__")
 check(environment.environment.ambient_light_energy==original.ambient_light_energy and not environment.environment.fog_enabled,"Lobby preserves lighting with fog disabled")
 for map in Assets.STONE:
  for i in 50:
   var p:=Vector3(i*.67,i*.16-2,i*1.1)
   var tint:=Assets.tint(map,p)
   check(tint.is_equal_approx(Assets.tint(map,Vector3(-p.x,p.y,-p.z))) and tint.r>=.86 and tint.g>=.86 and tint.b>=.85,"Bounded symmetric weathering "+map+" "+str(i))
 var path:="/tmp/fpsloppa-map-presentation-settings.cfg"
 var settings:=Preferences.defaults()
 for key in ["map_atmosphere","train_motion","surface_animation","surface_variation"]:settings[key]=false
 check(Preferences.save_settings(settings,path)==OK,"New settings save")
 var restored:=Preferences.read_settings(path)
 check(not restored.has("map_atmosphere") and restored.train_motion and restored.surface_animation and restored.surface_variation,"Retired atmosphere preference removed; default effects remain enabled")
 var legacy:=ConfigFile.new();legacy.load(path)
 for key in Preferences.ALWAYS_ENABLED:legacy.set_value("presentation",key,false)
 legacy.save(path);restored=Preferences.read_settings(path)
 check(Preferences.ALWAYS_ENABLED.all(func(key):return restored[key]),"Older disabled visual settings cannot turn off default effects")
 DirAccess.remove_absolute(path)
 level.free();game.free()
 print("MAP_PRESENTATION_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
