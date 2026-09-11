extends SceneTree
const Voice=preload("res://deathmatch/voice/chat.gd")
const Presentation=preload("res://deathmatch/settings/preferences.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
class Game extends Node:
	var headless:=true
	var voice_enabled:=true
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	var path:="/tmp/fpsloppa-client-settings-%d.cfg"%OS.get_process_id()
	var original:=ConfigFile.new();original.set_value("player","name","Config Marine");original.save(path)
	var game:=Game.new();var voice:=Voice.new();voice.game=game
	voice.load_preferences(path)
	check(voice.mode==1 and not voice.muted_all,"Fresh config enables push-to-talk by default")
	voice.set_mode(2);voice.muted_all=true;voice.threshold=.04;voice.input_device="Unavailable headset microphone";voice.save_preferences(path)
	var settings:=Presentation.defaults();settings.voice=.35;settings.texture_filter=1
	Presentation.save_settings(settings,path)
	voice.reset()
	check(voice.mode==2 and voice.muted_all and voice.threshold==.04,"Reconnect resets transport without resetting voice preferences")
	voice.set_mode(0) # Shutdown is deliberately transient.
	voice.free();voice=Voice.new();voice.game=game;voice.load_preferences(path)
	check(voice.mode==2 and voice.muted_all and voice.input_device=="Unavailable headset microphone","Restart restores mode, mute and preferred microphone; shutdown does not overwrite them")
	check(Presentation.read_settings(path).voice==.35 and Presentation.read_settings(path).texture_filter==1,"Voice volume and texture filtering survive config reload")
	original.load(path)
	check(original.get_value("player","name")=="Config Marine","Voice and graphics writes preserve other config sections")
	original.set_value("voice","mode","bad");original.set_value("voice","threshold",NAN);original.save(path)
	voice.load_preferences(path)
	check(voice.mode==1 and voice.threshold==.018,"Malformed voice config uses safe defaults")
	voice.free();game.free();DirAccess.remove_absolute(path)
	var image:=Image.create(32,32,false,Image.FORMAT_RGB8);image.fill(Color.WHITE)
	var material:=StandardMaterial3D.new();material.albedo_texture=ImageTexture.create_from_image(image)
	var filter:=Filtering.new();filter.material(material)
	check(material.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC and material.albedo_texture.get_image().has_mipmaps(),"Default map filtering is linear anisotropic with real mip levels")
	var shader_material:=ShaderMaterial.new();shader_material.shader=load("res://deathmatch/maps/baked_light.gdshader")
	shader_material.set_shader_parameter("base_texture",material.albedo_texture)
	filter.mode=0;filter.material(shader_material)
	check(shader_material.get_shader_parameter("texture_filter_mode")==0 and shader_material.get_shader_parameter("base_nearest")==shader_material.get_shader_parameter("base_texture"),"Pixelated setting updates baked-map samplers while preserving textures")
	filter=Filtering.new();filter.mode=1;filter.material(shader_material)
	check(shader_material.shader==Filtering.BAKED and shader_material.get_shader_parameter("texture_filter_mode")==1,"Trilinear setting also updates cached shader materials")
	print("CLIENT_PREFERENCES_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
