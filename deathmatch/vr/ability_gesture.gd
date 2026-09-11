extends RefCounted
## Head-relative controller motion; locomotion and turn transforms never enter this history.
var held:=false
var latched:=false
var busy:=false
var samples: Array=[]
var clock:=0.0
var armed_at:=0.0
var velocity:=Vector3.ZERO
func sample(position: Vector3,delta: float,grip: bool,trigger: bool,valid: bool) -> String:
	clock+=maxf(0,delta)
	if not valid or not position.is_finite() or delta<=0 or delta>.2:
		var cancel:=held;held=false;latched=grip or trigger;busy=grip or trigger;samples.clear();velocity=Vector3.ZERO
		return "cancel" if cancel else ""
	if not samples.is_empty() and position.distance_to(samples.back().position)>.65:
		samples.clear();held=false;latched=true;busy=true;velocity=Vector3.ZERO;return "cancel"
	samples.append({"position":position,"time":clock})
	while samples.size()>2 and clock-samples[0].time>.10:samples.pop_front()
	velocity=Vector3.ZERO
	if samples.size()>1:
		var elapsed: float=clock-samples[0].time
		if elapsed>.001:velocity=((position-samples[0].position)/elapsed).limit_length(12)
	if not grip and not trigger:latched=false;busy=false
	if held:
		busy=true
		if clock-armed_at>10:held=false;return "cancel"
		# Release either grip, or the trigger during a deliberate throwing stroke.
		if not grip or not trigger and velocity.length()>=1.4:
			held=false;return "throw"
	elif grip and trigger and not latched:
		latched=true;busy=true;held=true;armed_at=clock;return "arm"
	return ""
