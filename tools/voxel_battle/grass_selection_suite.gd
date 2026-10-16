extends "res://tools/voxel_battle/grass_test_suite.gd"
## Keep identical nonempty GPU buffers in both conditions; isolate selection computation.
const MIN_INSTANCES:=256
var drawing_locked:=false
var seed_instances:=0
var seed_hash:=""
var waiting_for_grass:=false
func setup(arena)->void:
 stages=[
  {"name":"A: selection ON, drawing held","selection":true,"draw":true,"audio":false,"play":false},
  {"name":"B: selection OFF, same drawing","selection":false,"draw":true,"audio":false,"play":false}]
 reset_player_on_start=false
 super.setup(arena)
func select_stage(index:int)->void:
 if capture:finish("condition_changed")
 stage=index
 var grass=game.battle_map.grass
 grass.set_enabled(true);grass.submit_enabled=not drawing_locked
 grass.selection_enabled=not drawing_locked or stages[stage].selection
 if not drawing_locked:grass.dirty=true;grass.update(game.world_view_camera())
 game.battle_map.environment_selection_enabled=true
 game.grass_audio.set_enabled(false);game.grass_audio.set_playback_enabled(false)
 settling=3.;reset_counters()
func toggle_capture()->void:
 if not capture and not drawing_locked and game.battle_map.grass.submitted_tufts<MIN_INSTANCES:
  waiting_for_grass=true
  print("GRASS_SELECTION_WAIT nonempty drawing required; walk into grass before START")
  return
 waiting_for_grass=false
 super.toggle_capture()
func lock_drawing()->bool:
 var grass=game.battle_map.grass
 if not drawing_locked:
  if grass.submitted_tufts<MIN_INSTANCES:return false
  seed_instances=grass.submitted_tufts;seed_hash=grass.drawing_hash();drawing_locked=true
  print("GRASS_SELECTION_DRAW_LOCKED ",JSON.stringify({"instances":seed_instances,"sha256":seed_hash}))
 grass.submit_enabled=false
 grass.selection_enabled=stages[stage].selection
 game.battle_map.environment_selection_enabled=true
 return true
func settle_complete()->void:
 if not capture:return
 if not lock_drawing():waiting_for_grass=true;finish("insufficient_grass_seed")
func _process(delta:float)->void:
 # Automated smoke validation seeds drawing from a resident grass tile. Live
 # headset runs always require the player to stand in a populated grass area.
 if not check_path.is_empty() and not drawing_locked:
  var grass=game.battle_map.grass
  var probe:=Camera3D.new();game.add_child(probe)
  for tile in grass.tiles.values():
   if tile.rows.is_empty():continue
   var row:Vector4=tile.rows[0];probe.global_position=Vector3(row.x,row.y+1.7,row.z)
   grass.dirty=true;grass.update(probe)
   if grass.submitted_tufts>=MIN_INSTANCES:break
  probe.free()
  if grass.submitted_tufts<MIN_INSTANCES:return
  if not lock_drawing():return
 super._process(delta)
 if not is_instance_valid(banner) or not is_instance_valid(game) or not game.active:return
 if waiting_for_grass or not drawing_locked and not capture:
  banner.text=stages[stage].name+"\nWalk into grass, then START: %d / %d instances"%[game.battle_map.grass.submitted_tufts,MIN_INSTANCES]
 elif drawing_locked:banner.text+="\nDrawing held: %d instances"%seed_instances
func extra_metadata()->Dictionary:
 var grass=game.battle_map.grass
 var current_hash:String=grass.drawing_hash()
 return {"selection_only":true,"drawing_locked":drawing_locked,"seed_instances":seed_instances,"seed_drawing_sha256":seed_hash,"end_drawing_sha256":current_hash,"drawing_unchanged":drawing_locked and current_hash==seed_hash and grass.submitted_tufts==seed_instances,"measurement":"CPU selection computation; GPU buffer submission held constant in both conditions"}
