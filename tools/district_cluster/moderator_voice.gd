extends Node
## One bounded global announcement stream; microphone opens only while PTT is held.
var client
var active:=false
var pending:=PackedVector2Array()
var transmitting:=false
var sequence:=0
var cursor:=0
var region:=""
var last: Dictionary={}
var native_rate:=48000
var held:=0.0
var speaker:=AudioStreamPlayer.new()
var label:=Label.new()
var heard:=0.0
func setup(owner_client,canvas: CanvasLayer) -> void:
	client=owner_client;add_child(speaker)
	var stream:=AudioStreamGenerator.new();stream.mix_rate=16000;stream.buffer_length=.4;speaker.stream=stream;speaker.volume_db=-2;speaker.play()
	label.position=Vector2(20,105);label.add_theme_color_override("font_color",Color(1,.8,.32));label.add_theme_font_size_override("font_size",20);canvas.add_child(label)
	poll()
func talk(enabled: bool) -> void:
	if enabled==active:return
	if enabled:
		if not is_instance_valid(client.moderator) or client.moderator.token.is_empty():return
		if AudioServer.set_input_device_active(true)!=OK:client.moderator.message.text="Microphone unavailable. Check the system input device.";return
		native_rate=AudioServer.get_input_mix_rate();held=0;pending.clear();active=true
	else:active=false;pending.clear();AudioServer.set_input_device_active(false)
func _process(delta: float) -> void:
	heard=maxf(0,heard-delta);label.visible=heard>0 or active
	client.soundscape.voice_duck=.45 if heard>0 or active else 1.0
	if not active:return
	held+=delta
	if not get_tree().root.has_focus() or held>30 or client.moderator.token.is_empty():talk(false);return
	label.text="GLOBAL BROADCAST · release F9 to stop"
	var count:=int(native_rate/10)
	pending.append_array(AudioServer.get_input_frames(maxi(0,count-pending.size())))
	if pending.size()<count:return
	var samples:=pending.slice(0,count);pending=pending.slice(count)
	if transmitting:return # Drop delayed capture, never queue stale speech.
	var bytes:=PackedByteArray();bytes.resize(3200)
	for i in 1600:
		var start:=int(float(i)*count/1600);var end:=maxi(start+1,int(float(i+1)*count/1600));var sum:=0.0
		for j in range(start,end):sum+=(samples[j].x+samples[j].y)*.5
		bytes.encode_s16(i*2,int(clampf(sum/(end-start),-.95,.95)*32767))
	send(bytes)
func send(bytes: PackedByteArray) -> void:
	transmitting=true;sequence+=1
	var reply: Dictionary=await client.request("moderator_voice",{"moderator_token":client.moderator.token,"sequence":sequence,"pcm":Marshalls.raw_to_base64(bytes)})
	transmitting=false
	if reply.has("error"):client.moderator.message.text=str(reply.error);talk(false)
func poll() -> void:
	while is_inside_tree():
		if not client.busy and not client.auth.is_empty():
			var next:=str(client.address)
			if next!=region:region=next;cursor=0
			var reply: Dictionary=await client.request("voice_poll",{"cursor":cursor})
			if reply.has("result"):
				cursor=int(reply.result.cursor)
				for packet in reply.result.frames:receive(packet)
		await get_tree().create_timer(.08).timeout
func receive(packet: Dictionary) -> void:
	if int(packet.id)==int(client.actor.id):return # Never play the moderator's own microphone back.
	if int(packet.sequence)<=int(last.get(packet.stream,-1)):return
	last[packet.stream]=int(packet.sequence)
	if last.size()>4:last={packet.stream:int(packet.sequence)}
	var bytes:=Marshalls.base64_to_raw(packet.pcm)
	if bytes.size()!=3200:return
	var samples:=PackedVector2Array();samples.resize(1600)
	for i in 1600:samples[i]=Vector2.ONE*clampf(float(bytes.decode_s16(i*2))/32768,-.95,.95)
	var playback: AudioStreamGeneratorPlayback=speaker.get_stream_playback()
	if playback.get_frames_available()<samples.size():playback.clear_buffer()
	playback.push_buffer(samples);heard=.5;label.text="GLOBAL · "+str(packet.name)
func _exit_tree() -> void:
	talk(false);speaker.stop();speaker.stream=null
	if is_instance_valid(label):label.queue_free()
