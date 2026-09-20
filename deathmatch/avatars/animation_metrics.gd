extends RefCounted
## Opt-in script timings; disabled in normal gameplay. Includes nested scopes.
static var enabled:=false
static var samples: Dictionary={}
static func begin() -> int:return Time.get_ticks_usec() if enabled else 0
static func end(label: String,start: int) -> void:
	if not enabled:return
	if not samples.has(label):samples[label]=[0,0]
	samples[label][0]+=Time.get_ticks_usec()-start
	samples[label][1]+=1
static func reset() -> void:samples.clear()
