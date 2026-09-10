extends Node
signal packet_decoded

var audioplayeropus = null
var audiostreamopus : AudioStreamOpus = null
var audio_stream_playback_opus : AudioStreamPlaybackOpus = null

# Consider looking at netem for simulating network traffic
# https://man7.org/linux/man-pages/man8/tc-netem.8.html

#frametimems = opusframesize*1000.0/opusframesize
var audioserveroutputlatency = AudioServer.get_output_latency()
@export var audio_buffer_lag_time_target = 0.6
@export var audio_buffer_lag_time_target_tolerance = 0.35

const asciiopenbrace = 123 # "{".to_ascii_buffer()[0]
const asciiclosebrace = 125 # "}".to_ascii_buffer()[0]
var lenchunkprefix = 2
var opusstreamcount = 0
var inopusstream = false
var opusframecount = 0
var opusframesize = 960
const Noutoforderqueue = 4
const Npacketinitialbatching = 2
var outoforderchunkqueue = [ ]
var opusframequeuecount = 0

var playbackpausedonmark = false

var lastemittedaudiobufferpitchscale = 1.0
var runninglagtimeminimum = -1.0


func _ready():
	audioplayeropus = get_parent().findaudioplayer() if get_parent().has_method("findaudioplayer") else get_parent()
	if audioplayeropus.has_method("set_stream"):
		audiostreamopus = AudioStreamOpus.new()
		audioplayeropus.set_stream(audiostreamopus)
	else:
		audioplayeropus = null
		assert(false, "Audiostream player not found!")


func setrecopusvalues(opus_sample_rate, opus_channels):
	if not audioplayeropus.playing or audiostreamopus.opus_sample_rate != opus_sample_rate or audiostreamopus.opus_channels != opus_channels:
		pass # Upstream diagnostic suppressed.
		audiostreamopus.opus_sample_rate = opus_sample_rate
		audiostreamopus.opus_channels = opus_channels
		audioplayeropus.play()  # creates a new playback
		audio_stream_playback_opus = audioplayeropus.get_stream_playback()
		set_sinewave_out(sinewaveoutmode)
		# begins in a paused state
		# audio_stream_playback_opus.mark_end_opus_stream(false)
		playbackpausedonmark = true
		pausereached = false

func unpausewhenbufferready():
	assert (playbackpausedonmark)
	var bufferlengthtime = audioserveroutputlatency + audio_stream_playback_opus.queue_length_frames()*1.0/audiostreamopus.opus_sample_rate
	if bufferlengthtime > audio_buffer_lag_time_target:
		audio_stream_playback_opus.mark_end_opus_stream(true)
		playbackpausedonmark = false
		runninglagtimeminimum = bufferlengthtime

func external_end_stream():
	if inopusstream:
		pass # Upstream diagnostic suppressed.
		receive_audio_packet(JSON.stringify({"talkingtimeend":-1}).to_ascii_buffer())

func receive_audio_packet(packet):
	if audiostreamopus == null:
		return
	if len(packet) <= 3:
		pass # Upstream diagnostic suppressed.
	elif packet[0] == asciiopenbrace and packet[-1] == asciiclosebrace:
		var h = JSON.parse_string(packet.get_string_from_ascii())
		if h != null:
			pass # Upstream diagnostic suppressed.

			if h.has("talkingtimestart"):
				setrecopusvalues(h["opussamplerate"], h.get("opuschannels", 2))
				lenchunkprefix = int(h["lenchunkprefix"])
				opusstreamcount = int(h["opusstreamcount"])
				opusframesize = int(h["opusframesize"])
				opusframecount = 0
				if h.get("opusframecount", 0) != 0:
					pass # Upstream diagnostic suppressed.
					opusframecount = int(h["opusframecount"]) + 1
				outoforderchunkqueue.clear()
				for i in range(Noutoforderqueue):
					outoforderchunkqueue.push_back(null)
				opusframequeuecount = 0
				assert (Npacketinitialbatching < Noutoforderqueue)
				runninglagtimeminimum = -1.0
				inopusstream = true

			elif h.has("talkingtimeend") and inopusstream:
				# Drain remaining reordered packets, including a one-frame PTT tap.
				for queued in outoforderchunkqueue:
					if queued != null:
						audio_stream_playback_opus.push_opus_packet(queued, lenchunkprefix, 0)
						packet_decoded.emit()
				outoforderchunkqueue.fill(null);opusframequeuecount=0
				audio_stream_playback_opus.mark_end_opus_stream(true)
				audio_stream_playback_opus.mark_end_opus_stream(false)
				playbackpausedonmark=true;pausereached=false;inopusstream=false

	elif lenchunkprefix == -1:
		pass

	elif lenchunkprefix == 0:
		audiostreamopus.push_opus_packet(packet, lenchunkprefix, 0)
		opusframecount += 1
		if playbackpausedonmark:
			unpausewhenbufferready()

	elif packet[1]&128 == (opusstreamcount%2)*128:
		assert (lenchunkprefix == 2)
		var opusframecountI = packet[0] + (packet[1]&127)*256
		var opusframecountR = opusframecountI - opusframecount
		if opusframecountR < 0:
			if opusframecountR < -30000:
				pass # Upstream diagnostic suppressed.
				opusframecount = opusframecountI
				opusframecountR = 0
			else:
				pass # Upstream diagnostic suppressed.
			
		if opusframecountR >= 0:
			while opusframecountR >= Noutoforderqueue:
				pass # Upstream diagnostic suppressed.
				if outoforderchunkqueue[0] != null:
					audio_stream_playback_opus.push_opus_packet(outoforderchunkqueue[0], lenchunkprefix, 0)
					packet_decoded.emit()
					opusframequeuecount -= 1
				else:
					var nextvalidpacketforfec = packet
					for i in range(1, Noutoforderqueue):
						if outoforderchunkqueue[i] != null:
							nextvalidpacketforfec = outoforderchunkqueue[i]
							break
					audio_stream_playback_opus.push_opus_packet(nextvalidpacketforfec, lenchunkprefix, 1)
					packet_decoded.emit()
				outoforderchunkqueue.pop_front()
				outoforderchunkqueue.push_back(null)
				opusframecountR -= 1
				opusframecount += 1
				assert (opusframequeuecount >= 0)

			if outoforderchunkqueue[opusframecountR] != null:return
			outoforderchunkqueue[opusframecountR] = packet
			opusframequeuecount += 1
			while outoforderchunkqueue[0] != null and opusframecount + opusframequeuecount >= Npacketinitialbatching:
				if opusframesize > audio_stream_playback_opus.available_space_frames():
					pass # Upstream diagnostic suppressed.
					break
				audio_stream_playback_opus.push_opus_packet(outoforderchunkqueue.pop_front(), lenchunkprefix, 0)
				packet_decoded.emit()
				outoforderchunkqueue.push_back(null)
				opusframecount += 1
				opusframequeuecount -= 1
				assert (opusframequeuecount >= 0)

		if playbackpausedonmark:
			unpausewhenbufferready()
	
	else:
		pass # Upstream diagnostic suppressed.

func setpitchscale(pitchscale):
	if pitchscale != lastemittedaudiobufferpitchscale:
		audioplayeropus.pitch_scale = pitchscale
		lastemittedaudiobufferpitchscale = pitchscale

var playingrecording = false
var pausereached = false
var prevskips = 0
func _physics_process(delta):
	if audio_stream_playback_opus == null:
		return
	if playingrecording:
		return
	var queuelengthframes = audio_stream_playback_opus.queue_length_frames()
	if not pausereached and queuelengthframes == 0:
		pausereached = true
		var currskips = audio_stream_playback_opus.get_skips(false)
		pass # Upstream diagnostic suppressed.
		prevskips = currskips
		
	var bufferlengthtime = audioserveroutputlatency + queuelengthframes*1.0/audiostreamopus.opus_sample_rate
	if not playbackpausedonmark:
		runninglagtimeminimum = bufferlengthtime
		if lastemittedaudiobufferpitchscale == 1.0:
			if abs(bufferlengthtime - audio_buffer_lag_time_target) > audio_buffer_lag_time_target_tolerance:
				setpitchscale(0.98 if (bufferlengthtime < audio_buffer_lag_time_target) else 1.02)
				pass # Upstream diagnostic suppressed.

		elif (lastemittedaudiobufferpitchscale < 1.0) == (bufferlengthtime > audio_buffer_lag_time_target):
			setpitchscale(1.0)
			pass # Upstream diagnostic suppressed.
	
	# leave the run-out at the same pitchscale
	#elif lastemittedaudiobufferpitchscale != 1.0:
	#	setpitchscale(1.0)
	#	print(" set lastemittedaudiobufferpitchscale to ", lastemittedaudiobufferpitchscale)


func replayrecording(speedup, recordedheader, recordedopuspackets, recordedfooter):
	playingrecording = true
	receive_audio_packet(JSON.stringify(recordedheader).to_ascii_buffer())
	setpitchscale(speedup)
	for x in recordedopuspackets:
		if recordedheader["opusframesize"] > audio_stream_playback_opus.available_space_frames():
			var tmm = audio_stream_playback_opus.queue_length_frames()*0.5/audiostreamopus.opus_sample_rate
			await get_tree().create_timer(tmm).timeout
		receive_audio_packet(x)
	receive_audio_packet(JSON.stringify(recordedfooter).to_ascii_buffer())
	playingrecording = false

var sinewaveoutmode = false
func set_sinewave_out(toggled_on):
	sinewaveoutmode = toggled_on
	if audio_stream_playback_opus:
		audio_stream_playback_opus.set_sinewave_frames(audiostreamopus.opus_sample_rate/440 if toggled_on else 0, 0.05)
