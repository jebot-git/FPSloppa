extends Node3D
## Cached prototype presentation; no lights, particles, or per-frame scripts.
func _ready() -> void:
	if DisplayServer.get_name()=="headless":return
	apply.call_deferred(get_tree().root)
static func apply(root: Node) -> void:
	var worlds:=root.find_children("*","WorldEnvironment",true,false)
	if worlds.is_empty():return
	var world: WorldEnvironment=worlds[0]
	var env: Environment=world.environment.duplicate()
	var material:=PanoramaSkyMaterial.new();material.panorama=load("res://deathmatch/maps/skies/night.png");material.energy_multiplier=.32
	var sky:=Sky.new();sky.sky_material=material;sky.radiance_size=Sky.RADIANCE_SIZE_128
	env.background_mode=Environment.BG_SKY;env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(.4,.5,.7);env.ambient_light_energy=.08
	env.fog_enabled=true;env.fog_light_color=Color(.10,.14,.23);env.fog_light_energy=.2;env.fog_density=.0012;env.fog_sky_affect=.12
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.glow_enabled=false
	world.environment=env
	for light in root.find_children("*","DirectionalLight3D",true,false):light.light_energy=.025;light.shadow_enabled=false
