extends RefCounted
## OpenXR axes: positive Y is up. A deliberate tilt and recenter confirms.
const ENTER:=0.60
const CENTER:=0.25
const RELEASE_DROP:=.12
var peak_radius:=0.0
var returning:=false
var opened:=false
var captures_stick:=false
var waiting_for_center:=false
var slots: Array=[]
var hover:=-1

static func sector(stick: Vector2,count: int) -> int:
	if count<=0 or not stick.is_finite():return -1
	return posmod(roundi(atan2(stick.x,stick.y)/TAU*count),count)

func open(owned: Array,stick: Vector2) -> void:
	if owned.is_empty():return
	slots=owned.duplicate();opened=true;captures_stick=true;hover=-1;peak_radius=0.0;returning=false
	waiting_for_center=not stick.is_finite() or stick.length()>CENTER

func close() -> void:
	opened=false;hover=-1;waiting_for_center=false
	# Keep consuming a tilted stick after cancel, until it has recentered.

func reset() -> void:
	close();captures_stick=false;slots.clear()

func sample(stick: Vector2) -> int:
	if not stick.is_finite():close();return -1
	var length:=minf(stick.length(),1.0)
	if not opened:
		if length<=CENTER:captures_stick=false
		return -1
	if waiting_for_center:
		if length<=CENTER:waiting_for_center=false
		return -1
	# An Index stick can shed Y before X when released from a diagonal.
	# Preserve the highlighted sector once it retreats, until centered or
	# deliberately pushed back out. Rotation around the outer ring still works.
	if hover>=0 and length<peak_radius-RELEASE_DROP:returning=true
	if returning and length>=peak_radius-.04:returning=false
	peak_radius=maxf(peak_radius,length)
	if length>=ENTER and not returning:hover=sector(stick,slots.size())
	elif length<=CENTER and hover>=0:
		var selected: int=slots[hover]
		close();captures_stick=false
		return selected
	return -1
