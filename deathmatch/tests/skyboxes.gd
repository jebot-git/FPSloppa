extends SceneTree
const Catalog=preload("res://deathmatch/maps/skies/catalog.gd")
const Atmosphere=preload("res://deathmatch/maps/atmosphere.gd")
var failures: Array=[]
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize() -> void:
 var audit: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://test-results/skyboxes/map-audit.json"))
 for row in audit.maps:
  if not Catalog.MAPS.has(row.id):continue
  check(row.visible_spawn_item_positions>0 and row.named_skybox.is_empty(),row.id+": selection has reachable sky evidence and no named skybox")
  check(Catalog.canonical("custom_"+row.sha256)==row.id,row.id+": exact server-download hash retains its sky selection")
  var sky:=Catalog.create(row.id)
  check(sky!=null and sky.sky_material is PanoramaSkyMaterial and sky.sky_material.panorama.get_size()==Vector2(2048,1024),row.id+": native panorama loads at bounded resolution")
  check(sky.sky_material.filter and sky.process_mode==Sky.PROCESS_MODE_QUALITY,row.id+": static filtered background")
 var game:=Node.new();root.add_child(game)
 var world:=WorldEnvironment.new();world.name="Environment";world.environment=Environment.new();game.add_child(world)
 var baseline:=world.environment;baseline.ambient_light_energy=.42;baseline.reflected_light_source=2;baseline.fog_enabled=true
 Atmosphere.apply(game,"tf_vesper")
 var night:=world.environment
 check(night.sky.sky_material is PanoramaSkyMaterial and is_equal_approx(night.ambient_light_energy,baseline.ambient_light_energy) and night.reflected_light_source==baseline.reflected_light_source,"Panorama preserves map lighting and reflection policy")
 Atmosphere.apply(game,"cc_ghostquarter")
 check(world.environment==night,"Maps with the same atmosphere and panorama reuse their environment")
 Atmosphere.apply(game,"tf_pressureworks")
 check(world.environment.sky.sky_material.panorama!=night.sky.sky_material.panorama,"Industrial and Gothic maps use different backgrounds")
 Atmosphere.apply(game,"qsrc_dm1")
 check(world.environment.sky.sky_material is ProceduralSkyMaterial,"Enclosed map has no new panorama")
 Atmosphere.apply(game,"external-map")
 check(not world.environment.fog_enabled and world.environment.ambient_light_energy==baseline.ambient_light_energy,"Unknown imported map keeps lighting, removes fog")
 Atmosphere.apply(game,"tf_vesper")
 check(world.environment.sky.sky_material is PanoramaSkyMaterial and not world.environment.fog_enabled,"Skies always active, fog always disabled")
 world.remove_meta("map_atmosphere_baseline");world.remove_meta("map_atmosphere_bank")
 world.environment=baseline
 var own:=Sky.new();own.sky_material=PanoramaSkyMaterial.new();baseline.sky=own
 Atmosphere.apply(game,"tf_vesper")
 check(world.environment.sky==own,"Explicit pre-existing sky is preserved")
 game.free();print("SKYBOX_RESULT ",failures);quit(0 if failures.is_empty() else 1)
