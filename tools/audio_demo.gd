extends SceneTree
## Desktop sound/model audition. Uses production assets and the spatial mixer;
## does not simulate damage, connect to a server, or save player preferences.
const Art=preload("res://deathmatch/art.gd")
const Rules=preload("res://deathmatch/experimental/weapon_rules.gd")
const SETS=["cs16","quake","ut99","tribes","doom"]
class Lobby extends RefCounted:
	func active():return false
class Mode extends RefCounted:
	var kind:="dm"
class Stage extends Node3D:
	var headless:=false
	var quitting:=false
	var active:=true
	var map_loading:=false
	var menu_open:=false
	var intermission:=0.0
	var clock:=0.0
	var current_map:="audio_showcase"
	var map_catalog: Array=[]
	var players: Dictionary={}
	var presentation:={"spatial_audio":"steam_audio"}
	var lobby=Lobby.new()
	var match_mode=Mode.new()
	var camera: Camera3D
	var armory=Rules.new()
	var music
var stage: Stage
var mixer
var model: Node3D
var flash: OmniLight3D
var title: Label
var status: Label
var set_index:=0
var slot:=0
var alternate:=false
var automatic:=true
var age:=0.0
var next_shot:=1.0
var recoil:=0.0
var keys: Dictionary={}
var ready:=false
func _initialize():run.call_deferred()
func run():
	var args:=OS.get_cmdline_user_args()
	if args.has("--set"):set_index=maxi(0,SETS.find(args[args.find("--set")+1]))
	if args.has("--slot"):slot=int(args[args.find("--slot")+1])
	if args.has("--paused"):automatic=false
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900)
	root.title="FPSloppa · Desktop weapon audio demo";Engine.max_fps=90
	stage=Stage.new();root.add_child(stage)
	stage.camera=Camera3D.new();stage.add_child(stage.camera)
	stage.camera.position=Vector3(0,1.65,2.8);stage.camera.fov=70;stage.camera.make_current()
	var environment:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("111e2b")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("a7c8e6");env.ambient_light_energy=.75
	environment.environment=env;stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-30,0);sun.light_energy=1.6;stage.add_child(sun)
	Art.box(stage,Vector3(0,-.12,-3),Vector3(18,.2,22),Art.material(Color("253647")))
	Art.box(stage,Vector3(0,2,-9),Vector3(18,4,.2),Art.material(Color("182736")))
	for x in [-6,-3,0,3,6]:Art.box(stage,Vector3(x,0,-3),Vector3(.025,.025,18),Art.material(Color("4c677b")))
	for z in range(-10,5,2):Art.box(stage,Vector3(0,0,z),Vector3(16,.025,.025),Art.material(Color("4c677b")))
	Art.box(stage,Vector3(0,1.5,-7),Vector3(1.3,2,.2),Art.material(Color("ba6e35")))
	flash=OmniLight3D.new();flash.light_color=Color("ffd69b");flash.omni_range=3;flash.light_energy=0
	stage.camera.add_child(flash);flash.position=Vector3(.2,-.1,-1)
	mixer=preload("res://deathmatch/audio/spatial.gd").new();stage.add_child(mixer);mixer.setup(stage)
	stage.music=preload("res://deathmatch/audio/music/player.gd").new();stage.add_child(stage.music);stage.music.setup(stage)
	var prefs=preload("res://deathmatch/settings/preferences.gd");var settings: Dictionary=prefs.read_settings()
	for bus in ["Master","ArenaEffects","ArenaMusic"]:prefs.bus_volume(bus,float(settings.get({"Master":"master","ArenaEffects":"effects","ArenaMusic":"music"}[bus],1.0)))
	var canvas:=CanvasLayer.new();root.add_child(canvas)
	title=Label.new();title.position=Vector2(42,34);title.add_theme_font_size_override("font_size",30);canvas.add_child(title)
	status=Label.new();status.position=Vector2(42,795);status.add_theme_font_size_override("font_size",20);canvas.add_child(status)
	var cross:=Label.new();cross.text="+";cross.position=Vector2(710,430);cross.add_theme_font_size_override("font_size",24);canvas.add_child(cross)
	select_weapon();ready=true;print("DESKTOP_AUDIO_DEMO_READY")
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	var screenshot: String=args[args.find("--screenshot")+1] if args.has("--screenshot") else "res://test-results/audio-refresh-20260930/desktop-demo.png"
	root.get_texture().get_image().save_png(screenshot)
func select_weapon():
	stage.armory.select(SETS[set_index]);slot=posmod(slot,stage.armory.table.size())
	if model:model.free()
	model=Art.weapon(slot,2,SETS[set_index]);stage.camera.add_child(model)
	model.position=Vector3(.26,-.25,-.65);model.rotation=Vector3.ZERO
	age=0;next_shot=.7;recoil=0
	print("AUDIO_DEMO_WEAPON ",SETS[set_index]," ",slot," ",stage.armory.data(slot).name)
func pressed(key: int) -> bool:
	var held:=Input.is_physical_key_pressed(key);var before: bool=keys.get(key,false);keys[key]=held;return held and not before
func fire():
	var rules: String=SETS[set_index]
	var kind: String=("weapon_" if rules=="doom" else rules+"_weapon_")+str(slot)
	if alternate and rules in ["ut99","cs16"]:kind+="_alt"
	mixer.play(kind,stage.camera.global_position+Vector3(.2,-.15,-.65),-10 if alternate and rules=="cs16" and slot in [2,7] else -4)
	if rules=="cs16":preload("res://deathmatch/counterstrike/models.gd").fire(model)
	Art.fire(model,slot,rules,float(stage.armory.data(slot,alternate).cycle))
	recoil=1;flash.light_energy=1.5
func _process(delta: float) -> bool:
	if not ready:return false
	stage.clock+=delta;age+=delta
	if pressed(KEY_ESCAPE):stage.quitting=true;mixer.clear();stage.music.stop();stage.queue_free();quit();return false
	if pressed(KEY_SPACE):automatic=not automatic;age=0;next_shot=.2
	if pressed(KEY_RIGHT):slot+=1;select_weapon()
	if pressed(KEY_LEFT):slot-=1;select_weapon()
	if pressed(KEY_TAB):set_index=(set_index+1)%SETS.size();slot=0;alternate=false;select_weapon()
	if pressed(KEY_A):alternate=not alternate;age=0;next_shot=.2
	var click:=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if click and not keys.get(-1,false):fire()
	keys[-1]=click
	if automatic:
		if age>=5:
			slot+=1
			if slot>=stage.armory.table.size():slot=0;set_index=(set_index+1)%SETS.size();alternate=false
			select_weapon()
		elif age>=next_shot and age<3.7:
			fire();next_shot=age+maxf(.16,float(stage.armory.data(slot,alternate).cycle))
	recoil=move_toward(recoil,0,delta*6);model.position.z=-.65+recoil*.08;model.rotation.x=recoil*.06
	flash.light_energy=move_toward(flash.light_energy,0,delta*30)
	title.text=Rules.NAMES[SETS[set_index]]+"\n"+str(slot+1)+" / "+str(stage.armory.table.size())+"   "+stage.armory.data(slot).name+(" · ALTERNATE / SUPPRESSED" if alternate else " · PRIMARY")
	status.text=("AUTO TOUR · 5 seconds per weapon" if automatic else "PAUSED · Click to fire")+"\n← / → weapon   Tab weapon set   A primary / alternate   Space pause / resume   Esc close\n"+("Custom BGM active · ambience suspended" if stage.music.has_custom_bgm() else "Map ambience: "+mixer.ambience.profile)+" · Sound/model audition; no damage simulation"
	return false
