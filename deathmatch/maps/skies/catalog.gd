extends RefCounted
## Audited base-map backgrounds only; unknown/user-authored maps keep their sky.
const TEXTURES={
 "overcast":"res://deathmatch/maps/skies/overcast.png",
 "night":"res://deathmatch/maps/skies/night.png",
 "storm":"res://deathmatch/maps/skies/storm.png",
 "winter":"res://deathmatch/maps/skies/winter.png",
 "ember":"res://deathmatch/maps/skies/ember.png"
}
const MAPS={
 "as_hislop":["storm",.75],"as_frigate":["overcast",.85],
 "tf_pressureworks":["storm",.75],"tf_vesper":["night",.9],
 "koth_solstice":["winter",.85],"koth_torture":["ember",.7],"koth_hyperborea":["winter",.85],
 "cc_hyperborea":["winter",.85],"cc_psychofuge":["ember",.7],"cc_ghostquarter":["night",.9],
 "qsrc_dm2":["ember",.7],"qsrc_dm3":["storm",.75],"qsrc_dm4":["night",.9],
 "qsrc_dm5":["night",.9],"qsrc_dm6":["night",.9],"qsrc_dm7":["winter",.85],
 "ctf_crownreach":["night",.9]
}
static var source_maps: Dictionary={}
static func canonical(map: String) -> String:
 if not map.begins_with("custom_"):return map
 if source_maps.is_empty():
  var sources: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/skies/SOURCES.json"))
  source_maps=sources.get("map_sources",{})
 return str(source_maps.get(map.trim_prefix("custom_"),map))
static func create(map: String) -> Sky:
 map=canonical(map)
 if not MAPS.has(map):return null
 var choice: Array=MAPS[map]
 var texture:=load(TEXTURES[choice[0]]) as Texture2D
 if not texture:return null
 var material:=PanoramaSkyMaterial.new()
 material.panorama=texture;material.filter=true;material.energy_multiplier=choice[1]
 var sky:=Sky.new();sky.sky_material=material
 sky.process_mode=Sky.PROCESS_MODE_QUALITY;sky.radiance_size=Sky.RADIANCE_SIZE_128
 return sky
