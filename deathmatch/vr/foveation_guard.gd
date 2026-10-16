extends Node
## Reapply after session/swapchain transitions, rather than every rendered frame.
const Foveation=preload("res://deathmatch/vr/foveation.gd")
var viewport:Viewport
var xr
var values:Dictionary={}
var pending_frames:=0
var poll_elapsed:=0.0
var last_state:Array=[]
var last_report:Dictionary={}

func configure(target:Viewport,runtime,settings:Dictionary)->void:
	if xr!=runtime:
		if xr:
			for event in ["session_begun","session_synchronized","session_focussed"]:
				if xr.has_signal(event) and xr.is_connected(event,refresh):xr.disconnect(event,refresh)
		xr=runtime
		if xr:
			for event in ["session_begun","session_synchronized","session_focussed"]:
				if xr.has_signal(event) and not xr.is_connected(event,refresh):xr.connect(event,refresh)
	viewport=target;values=settings.duplicate();refresh()
	apply_settings(false)

func refresh()->void:
	pending_frames=30

func state()->Array:
	if xr==null or not xr.is_initialized():return [false]
	return [true,xr.is_eye_gaze_interaction_supported(),xr.is_foveation_supported(),xr.render_target_size_multiplier,xr.get_render_target_size(),viewport.vrs_mode,xr.foveation_level,xr.foveation_dynamic,xr.vrs_min_radius,xr.vrs_strength]

func apply_settings(force_profile:bool)->void:
	if viewport==null or values.is_empty():return
	# Resize first: changing the swapchain can invalidate a previously set profile.
	if xr and xr.is_initialized() and not is_equal_approx(xr.render_target_size_multiplier,float(values.render_scale)):
		xr.render_target_size_multiplier=float(values.render_scale)
	viewport.scaling_3d_scale=1.0
	last_report=Foveation.apply(viewport,xr,int(values.foveation_level),int(values.fovea_size),bool(values.get("foveation_dynamic",true)),force_profile)
	if xr and xr.is_initialized():
		last_report["render_scale"]=xr.render_target_size_multiplier
		last_report["target_size"]=str(xr.get_render_target_size())
	last_state=state()
	if force_profile:print("XR_FOVEATION_APPLIED ",JSON.stringify(last_report))

func _process(delta:float)->void:
	if viewport==null:return
	if pending_frames>0:
		pending_frames-=1
		if pending_frames in [28,22,0]:apply_settings(true)
	poll_elapsed+=delta
	if poll_elapsed<.5:return
	poll_elapsed=0.0
	if state()!=last_state:
		apply_settings(false);refresh()
