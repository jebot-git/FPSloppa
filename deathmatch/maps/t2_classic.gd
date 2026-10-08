extends RefCounted
## Classic pack IDs are stable across source/cached/client/server builds.
const IDS=["ctf_t2_acidrain", "ctf_t2_blastside", "ctf_t2_broadside", "ctf_t2_confusco", "ctf_t2_dangerouscrossing", "ctf_t2_desertofdeath", "ctf_t2_gorgon", "ctf_t2_hillside", "ctf_t2_iceridge", "ctf_t2_lakefront", "ctf_t2_magmatic", "ctf_t2_ramparts", "ctf_t2_rollercoaster", "ctf_t2_sandstorm", "ctf_t2_scarabrae", "ctf_t2_shockridge", "ctf_t2_snowblind", "ctf_t2_starfallen", "ctf_t2_subzero", "ctf_t2_surreal", "ctf_t2_titan", "ctf_t2_whitedwarf"]
static func installed_rotation() -> Array:
 var result: Array=["ctf_stonehenge","ctf_raindance","ctf_katabatic"]
 for id in IDS:
  if FileAccess.file_exists(preload("res://deathmatch/assets/paths.gd").resolve("res://maps/"+id+".bsp")):result.append(id)
 return result
