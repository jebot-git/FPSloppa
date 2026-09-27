extends RefCounted
## OpenXR axes: positive Y is up. A deliberate tilt and recenter confirms.
const ENTER:=0.60
const CENTER:=0.25
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
	slots=owned.duplicate();opened=true;captures_stick=true;hover=-1
	waiting_for_center=not stick.is_finite() or stick.length()>CENTER

func close() -> void:
	opened=false;hover=-1;waiting_for_center=false
	# Keep consuming a tilted stick after cancel, until it has recentered.

func reset() -> void:
	close();captures_stick=false;slots.clear()

func sample(stick: Vector2) -> int:
	if not stick.is_finite():close();return -1
	var length:=stick.length()
	if not opened:
		if length<=CENTER:captures_stick=false
		return -1
	if waiting_for_center:
		if length<=CENTER:waiting_for_center=false
		return -1
	if length>=ENTER:hover=sector(stick,slots.size())
	elif length<=CENTER and hover>=0:
		var selected: int=slots[hover]
		close();captures_stick=false
		return selected
	return -1
