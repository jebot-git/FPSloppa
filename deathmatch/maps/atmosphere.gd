extends RefCounted
## Default static skies. Fog is disabled for every map, including imports.
const Skies=preload("res://deathmatch/maps/skies/catalog.gd")
const PROFILES={
 "abbey":[Color(.025,.04,.095),Color(.22,.27,.36)],
 "works":[Color(.16,.23,.29),Color(.48,.48,.40)],
 "coast":[Color(.10,.22,.34),Color(.42,.52,.56)],
 "inferno":[Color(.08,.055,.06),Color(.31,.22,.18)],
 "void":[Color(.013,.02,.06),Color(.11,.16,.25)]
}
const MAPS={
 "tf_vesper":"abbey","tf_pressureworks":"works","as_hislop":"works","as_frigate":"coast",
 "koth_solstice":"coast","koth_torture":"abbey","koth_hyperborea":"coast","koth_alichar":"abbey",
 "cc_hyperborea":"coast","cc_psychofuge":"inferno","cc_ghostquarter":"abbey","cc_basement":"inferno",
 "qsrc_dm1":"inferno","qsrc_dm2":"inferno","qsrc_dm3":"works","qsrc_dm4":"inferno","qsrc_dm5":"abbey","qsrc_dm6":"abbey","qsrc_dm7":"coast",
 "ctf_tideworks":"coast","ctf_crucible":"works","ctf_confluence":"coast","ctf_deepvault":"abbey","ctf_crownreach":"abbey","ctf_skyfracture":"void"
}
static func apply(game: Node,map: String) -> void:
 map=Skies.canonical(map)
 var world:=game.get_node_or_null("Environment") as WorldEnvironment
 if not world or not world.environment:return
 if not world.has_meta("map_atmosphere_baseline"):
  var clean:=world.environment.duplicate() as Environment
  clean.fog_enabled=false;clean.volumetric_fog_enabled=false
  world.set_meta("map_atmosphere_baseline",clean)
 var baseline: Environment=world.get_meta("map_atmosphere_baseline")
 if not MAPS.has(map):world.environment=baseline;return
 var profile_key: String=MAPS[map]
 var key: String=str(Skies.MAPS[map]) if Skies.MAPS.has(map) else profile_key
 var bank: Dictionary=world.get_meta("map_atmosphere_bank",{})
 if not bank.has(key):
  var profile: Array=PROFILES[profile_key]
  var env:=baseline.duplicate() as Environment
  var authored: bool=baseline.sky!=null and baseline.sky.sky_material!=null and not baseline.sky.sky_material is ProceduralSkyMaterial
  var sky: Sky=baseline.sky if authored else Skies.create(map)
  if not sky:
   sky=Sky.new();var material:=ProceduralSkyMaterial.new()
   material.sky_top_color=profile[0];material.sky_horizon_color=profile[1]
   material.ground_horizon_color=profile[1];material.ground_bottom_color=profile[0]
   material.sun_angle_max=8.0
   sky.sky_material=material;sky.process_mode=Sky.PROCESS_MODE_QUALITY;sky.radiance_size=Sky.RADIANCE_SIZE_128
  env.sky=sky
  bank[key]=env;world.set_meta("map_atmosphere_bank",bank)
 world.environment=bank[key]
