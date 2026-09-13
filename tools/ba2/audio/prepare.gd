extends SceneTree
func _initialize() -> void:
	for i in 3:
		var stream:=AudioStreamWAV.load_from_file("res://tools/ba2/audio/stomp_%d.wav"%i)
		assert(stream and stream.get_length()>1.4 and stream.get_length()<1.5)
		assert(ResourceSaver.save(stream,"res://deathmatch/audio/ba2/stomp_%d.res"%i,ResourceSaver.FLAG_COMPRESS)==OK)
	print("BA2_STOMP_ASSETS_READY");quit()
