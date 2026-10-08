extends RefCounted
## Static skies, with restrained distance haze on outdoor ST maps.
const Skies=preload("res://deathmatch/maps/skies/catalog.gd")
const PROFILES={
 "desert":[Color(.27,.46,.66),Color(.78,.72,.59)],
 "abbey":[Color(.025,.04,.095),Color(.22,.27,.36)],
 "works":[Color(.16,.23,.29),Color(.48,.48,.40)],
 "coast":[Color(.10,.22,.34),Color(.42,.52,.56)],
 "inferno":[Color(.08,.055,.06),Color(.31,.22,.18)],
 "void":[Color(.013,.02,.06),Color(.11,.16,.25)]
}
const MAPS={
 "ctf_t2_acidrain":"desert",
 "ctf_t2_blastside":"works",
 "ctf_t2_broadside":"works",
 "ctf_t2_confusco":"desert",
 "ctf_t2_dangerouscrossing":"works",
 "ctf_t2_desertofdeath":"desert",
 "ctf_t2_gorgon":"desert",
 "ctf_t2_hillside":"works",
 "ctf_t2_iceridge":"coast",
 "ctf_t2_lakefront":"works",
 "ctf_t2_magmatic":"inferno",
 "ctf_t2_ramparts":"works",
 "ctf_t2_rollercoaster":"desert",
 "ctf_t2_sandstorm":"desert",
 "ctf_t2_scarabrae":"works",
 "ctf_t2_shockridge":"coast",
 "ctf_t2_snowblind":"coast",
 "ctf_t2_starfallen":"works",
 "ctf_t2_subzero":"coast",
 "ctf_t2_surreal":"works",
 "ctf_t2_titan":"works",
 "ctf_t2_whitedwarf":"inferno",

 "ctf_stonehenge":"works",
 "ctf_raindance":"works",
 "ctf_katabatic":"coast",
 "tb_cindercoil":"works",
 "de_dust2_rebuilt":"desert","de_nuke_rebuilt":"desert","de_inferno_rebuilt":"desert","de_aztec_rebuilt":"works","de_train_rebuilt":"coast",
 "tf_vesper":"abbey","tf_pressureworks":"works","as_hislop":"works","as_frigate":"coast",
 "koth_solstice":"coast","koth_torture":"abbey","koth_hyperborea":"coast","koth_alichar":"abbey",
 "cc_hyperborea":"coast","cc_psychofuge":"inferno","cc_ghostquarter":"abbey","cc_basement":"inferno",
 "qsrc_dm1":"inferno","qsrc_dm2":"inferno","qsrc_dm3":"works","qsrc_dm4":"inferno","qsrc_dm5":"abbey","qsrc_dm6":"abbey","qsrc_dm7":"coast",
 "ctf_tideworks":"coast","ctf_crucible":"works","ctf_confluence":"coast","ctf_deepvault":"abbey","ctf_crownreach":"abbey","ctf_skyfracture":"void"
}
const DISTANCE_FOG={
 "ctf_t2_acidrain":[322.5,900.0,0.28,Color(0.25,0.25,0.32)],
 "ctf_t2_blastside":[225.0,1170.0,0.2,Color(0.7,0.75,0.75)],
 "ctf_t2_broadside":[225.0,1170.0,0.2,Color(0.7,0.75,0.75)],
 "ctf_t2_confusco":[225.0,1080.0,0.28,Color(0.5,0.3,0.2)],
 "ctf_t2_dangerouscrossing":[165.0,756.0,0.2,Color(0.7,0.7,0.7)],
 "ctf_t2_desertofdeath":[150.0,810.0,0.28,Color(0.12,0.12,0.12)],
 "ctf_t2_gorgon":[225.0,900.0,0.28,Color(0.8,0.5,0.35)],
 "ctf_t2_hillside":[337.5,900.0,0.2,Color(0.57,0.64,0.8)],
 "ctf_t2_iceridge":[225.0,1035.0,0.28,Color(0.6,0.6,0.65)],
 "ctf_t2_lakefront":[225.0,855.0,0.2,Color(0.5,0.5,0.5)],
 "ctf_t2_magmatic":[210.0,900.0,0.28,Color(0.8,0.383,0.12)],
 "ctf_t2_ramparts":[206.2,810.0,0.28,Color(0.62,0.64,0.742)],
 "ctf_t2_rollercoaster":[112.5,720.0,0.28,Color(0.8,0.7,0.5)],
 "ctf_t2_sandstorm":[150.0,850.0,0.3,Color(0.8,0.6,0.4)],
 "ctf_t2_scarabrae":[187.5,900.0,0.2,Color(0.7,0.75,0.8)],
 "ctf_t2_shockridge":[150.0,900.0,0.28,Color(0.4,0.59,0.6)],
 "ctf_t2_snowblind":[100.0,700.0,0.32,Color(0.65,0.65,0.65)],
 "ctf_t2_starfallen":[315.0,1008.0,0.2,Color(0.26,0.41,0.44)],
 "ctf_t2_subzero":[150.0,900.0,0.28,Color(0.65,0.65,0.7)],
 "ctf_t2_surreal":[337.5,954.0,0.2,Color(0.5,0.6,0.75)],
 "ctf_t2_titan":[262.5,810.0,0.2,Color(0.71,0.71,0.71)],
 "ctf_t2_whitedwarf":[300.0,900.0,0.2,Color(0.12,0.22,0.12)],

 "ctf_stonehenge":[240.0,950.0,.22,Color(.43,.49,.53)],
 "ctf_raindance":[300.0,1200.0,.22,Color(.39,.47,.51)],
 "ctf_katabatic":[350.0,1400.0,.28,Color(.62,.70,.78)]
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
 if DISTANCE_FOG.has(map):key=map+key
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
  distance_fog(env,map)
  bank[key]=env;world.set_meta("map_atmosphere_bank",bank)
 world.environment=bank[key]
static func distance_fog(env: Environment,map: String) -> void:
 if not DISTANCE_FOG.has(map):return
 var profile: Array=DISTANCE_FOG[map]
 env.fog_enabled=true;env.fog_mode=Environment.FOG_MODE_DEPTH
 env.fog_depth_begin=profile[0];env.fog_depth_end=profile[1]
 env.fog_depth_curve=1.5;env.fog_density=profile[2];env.fog_light_color=profile[3]
 env.fog_sky_affect=0;env.fog_height_density=0;env.volumetric_fog_enabled=false
