extends SceneTree
const Host=preload("res://tools/authority_core/host.gd")
const Codec=preload("res://deathmatch/native/authority_protocol.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var host:=Host.new();root.add_child(host);host.cq_mode=true
 host.weapon_manifest=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/weapons/cq/manifest.json"))
 var file:=FileAccess.open("res://native_server/cooked/benchmark-inputs.bin",FileAccess.WRITE);file.store_buffer("CQB1".to_ascii_buffer());file.store_32(8);file.store_32(600)
 for variant in 8:
  var role:=variant%4
  host.player_weapon=[4,9,3,5][role]
  for sample in 600:
   host.animation_phase=sample*.5
   var c:={"life":1,"seq":sample+1,"move":Vector2.ZERO,"yaw":0.,"pitch":.6,"weapon":host.player_weapon,"fire":false,"jump":false,"reload":false,"slow":false,"crouch":false,"prone":false,"blocked":false,"view_time":-1.}
   host.tracked_command(c,variant/4);var bytes:=Codec.encode_input(c);file.store_32(bytes.size());file.store_buffer(bytes)
 file.close();print("CQ_BENCHMARK_INPUTS 4 classes, 600 samples per 10 second cycle");host.free();quit()
