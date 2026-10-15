extends SceneTree
func _initialize()->void:
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/audio/cq_field/manifest.json"))
 for key in manifest:
  var row:Dictionary=manifest[key];var path:String="res://deathmatch/audio/cq_field/"+row.file
  assert(not FileAccess.file_exists(path),"Fixture must test imported resources without loose source audio")
  var stream:AudioStream=load(path);assert(stream!=null and absf(stream.get_length()-row.seconds)<.01,key)
  if stream is AudioStreamOggVorbis:stream=stream.duplicate();stream.loop=true;assert(stream.loop)
 print("CQ_FIELD_AUDIO_PACK_PASS ",manifest.size());quit()
