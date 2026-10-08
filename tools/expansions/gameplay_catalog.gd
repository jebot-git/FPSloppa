extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const DE=preload("res://deathmatch/modes/defusal_maps.gd")
const Config=preload("res://deathmatch/server/config.gd")
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 if not ok:failures.append(label);push_error(label)
func run():
 DE.converted.clear()
 var rows:=Loader.catalog();var st:=Loader.choices_for_mode(rows,"st");var de: Array=[]
 for row in rows:
  if row.get("distribution","base")!="base":continue
  if "de" in row.get("modes",[]):
   check(DE.supported(row.id,row.sha256),"Missing base DE objectives: "+row.id)
   check(not DE.supported(row.id,"wrong-hash"),"Accepted stale objective hash: "+row.id)
   de.append(row.id)
 check(de.size()==16 and st.size()==25,"Wrong expansion map counts")
 for id in preload("res://deathmatch/release_features.gd").retired:
  check(not rows.any(func(row):return row.id==id),"Retired map remains selectable: "+id)
  check(not DE.installed(id),"Retired map remains installed: "+id)
  check(Config.parse('set sv_gametype "de"\nset de_maplist "'+id+'"').has("error"),"Retired rotation accepted: "+id)
 var cfg:=Config.parse('set sv_gametype "de"\nmap de_varq_dust2')
 check(not cfg.has("error"),"Converted base DE config rejected")
 if not cfg.has("error"):check(cfg.values.maps.size()==16,"Default DE server rotation omits expansion")
 var result:={"de":de,"st":st,"failures":failures}
 FileAccess.open("res://tools/expansions/gameplay_catalog.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("EXPANSION_CATALOG ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
