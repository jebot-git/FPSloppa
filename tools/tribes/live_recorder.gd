extends RefCounted
## Spectator viewport only. Game-clock anchors let accelerated footage be
## compared with authoritative events without assuming perfect wall pacing.
var encoder: Dictionary={}
var started:=0
var frames:=0
var duplicates:=0
var anchors: Array=[]
var output: String
func start(folder: String):
	output=folder
	encoder=OS.execute_with_pipe("/usr/bin/ffmpeg",["-loglevel","error","-y","-f","rawvideo","-pixel_format","rgb24","-video_size","1280x800","-framerate","30","-i","pipe:0","-an","-c:v","libx264","-preset","veryfast","-crf","23","-pix_fmt","yuv420p","-movflags","+faststart",output+"/match.mp4"],true)
	assert(encoder.has("stdio"));started=Time.get_ticks_usec()
func capture(viewport: Viewport,game_clock: float,focus: int,speed_kmh: float):
	if encoder.is_empty():return
	var wanted:=int((Time.get_ticks_usec()-started)*30/1000000)+1
	if wanted<=frames:return
	var img:=viewport.get_texture().get_image()
	if img.get_size()!=Vector2i(1280,800):img.resize(1280,800,Image.INTERPOLATE_BILINEAR)
	img.convert(Image.FORMAT_RGB8);var data:=img.get_data()
	if frames/30<wanted/30 or frames==0:anchors.append({"video_seconds":frames/30.0,"game_seconds":game_clock,"bot":focus,"horizontal_speed_kmh":speed_kmh})
	duplicates+=maxi(0,wanted-frames-1)
	while frames<wanted:
		assert(encoder.stdio.store_buffer(data),"Spectator video encoder failed");frames+=1
func finish() -> int:
	if encoder.is_empty():return 0
	encoder.stdio.close()
	FileAccess.open(output+"/video.json",FileAccess.WRITE).store_string(JSON.stringify({"frames":frames,"seconds":frames/30.0,"duplicate_frames":duplicates,"anchors":anchors,"clock_basis":"server_snapshot_time","capture":"Silent Vulkan spectator viewport, wall-clock paced at 30 fps"},"  "))
	return encoder.pid
