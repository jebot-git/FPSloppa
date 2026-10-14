extends SceneTree
## Native Forward+ check of the production designation draw path and both visor grades.
const Arena=preload("res://tools/voxel_battle/class_arena.gd")
const OUTPUT:="res://test-results/designator-nvg"
class TestArena extends Arena:
	func _ready() -> void:
		classes.setup(self);night_vision.setup(self);camera=$Overview
var game
var effect=preload("res://deathmatch/conquest/classes/night_vision_effect.gd").new()
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,800);DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.players[1]={"team":0,"dead":false,"spectator":false};game.classes.ensure(1)
	game.camera.position=Vector3(0,1.7,0);game.camera.look_at(Vector3(0,1.7,-8));game.camera.fov=85
	var env:WorldEnvironment=game.get_node("Environment");env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color.BLACK;env.compositor=Compositor.new();env.compositor.compositor_effects=[effect]
	game.designations[2]={"team":1,"start":Vector3(-5,1.7,-8),"position":Vector3(5,1.7,-8),"until":100}
	for mode in ["off","standard","scout","off-again"]:
		var enabled:bool=mode in ["standard","scout"]
		game.classes.states[1]["nv"]=enabled;game.draw_class_tools();effect.configure(6000,mode=="scout",0,1);effect.enabled=enabled
		await create_timer(.5).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT+"/"+mode+".png")
		var mesh:MeshInstance3D=game.class_visuals.enemy_beam
		assert(mesh.mesh.get_surface_count()==(1 if enabled else 0))
		assert(is_equal_approx(mesh.material_override.albedo_color.a,1 if enabled else .12))
		print("DESIGNATOR_NVG_CAPTURE ",mode)
	effect.enabled=false;RenderingServer.call_on_render_thread(effect.release);quit()
