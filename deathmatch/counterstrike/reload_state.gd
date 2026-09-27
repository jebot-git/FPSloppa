extends RefCounted
## Pure physical interaction state. The authority supplies validated controller
## poses; this never accepts client-supplied ammunition or completion events.
const PHYSICAL:=1
const MAGAZINE:=2
const CHAMBERED:=4
const RACK_GRIP:=8
const COVER_GRIP:=16
const SLIDE_LOCK:=32
const GRAB_RADIUS:=.105
const Hip=preload("res://deathmatch/vr/hip_mount.gd")
const DRAW_DISTANCE:=.12
const INSERT_RADIUS:=.095
const MIN_STROKE_TIME:=.10
const RACK_POINTS=[Vector3.ZERO,Vector3(0,.14,-.04),Vector3(0,.14,-.04),Vector3(0,.055,-.51),Vector3(.079,.101,-.19),Vector3(-.044,.144,-.445),Vector3(.084,.106,-.19),Vector3(0,.142,.055),Vector3(.114,.078,-.29),Vector3(.077,.043,.006),Vector3(0,.15,-.04),Vector3(.09,.106,-.438)]
const MAG_POINTS=[Vector3.ZERO,Vector3(0,-.12,.066),Vector3(0,-.12,.049),Vector3(0,.02,-.235),Vector3(0,.02,-.235),Vector3(0,-.06,-.237),Vector3(0,-.08,-.275),Vector3(0,-.08,-.244),Vector3(-.027,-.13,-.335),Vector3(0,-.09,-.291),Vector3(0,-.14,.058),Vector3(0,.153,-.224)]
const COVER_POINT:=Vector3(0,.23,-.10)
const COVER_PIVOT:=Vector3(0,.145,-.424)
static func cover_point(amount: float) -> Vector3:
	return COVER_PIVOT+Basis(Vector3.RIGHT,-amount*deg_to_rad(80))*(COVER_POINT-COVER_PIVOT)
static func tube_fed(w: int) -> bool:return w in [3,4]
static func manual_cycle(w: int) -> bool:return w in [3,9]
static func make(clip: int) -> Dictionary:
	return {"mag":true,"ready":clip>0,"locked":clip==0,"cover":0.0,"stroke":0.0,"carry":0,"grab":"","grip":true,"eject":true,"pulled":false,"started":0.0,"anchor":Vector3.ZERO,"base":0.0,"left_pouch":false,"side":-1,"supported":false,"event":0}
static func interrupt(p: Dictionary):
	# Loss of tracking, menus and holstering never complete a stroke or insert ammo.
	p.grab="";p.grip=true;p.eject=true;p.carry=0;p.stroke=0.0;p.pulled=false;p.left_pouch=false;p.supported=false
static func flags(p: Dictionary) -> int:
	return PHYSICAL|(MAGAZINE if p.mag else 0)|(CHAMBERED if p.ready else 0)|(RACK_GRIP if p.grab=="rack" else 0)|(COVER_GRIP if p.grab=="cover" else 0)|(SLIDE_LOCK if p.locked else 0)
static func pouch(pose: Dictionary) -> Transform3D:
	return Hip.pouch(pose)
static func model_pose(pose: Dictionary,w: int) -> Transform3D:
	var art=load("res://deathmatch/art.gd")
	return art.held_transform(pose.weapon,w,art.VR_SCALE,"cs16")
static func wants_pouch(w: int,p: Dictionary,clip: int,total: int,capacity: int) -> bool:
	return total>clip and clip<capacity and (tube_fed(w) or not p.mag)
static func can_fire(p: Dictionary,w: int) -> bool:
	return p.mag and p.ready and p.cover<.05 and p.grab!="rack" and p.grab!="cover" and p.stroke<.05
static func chamber(p: Dictionary,clip: int):
	p.ready=p.mag and clip>0 and p.cover<.05;p.locked=p.mag and clip==0;p.stroke=0.0;p.pulled=false;p.event+=1
static func sample(p: Dictionary,w: int,clip: int,total: int,capacity: int,pose: Dictionary,grip: bool,eject: bool,now: float,enabled: bool=true) -> int:
	if not enabled or pose.is_empty() or not pose.has("offhand_weapon"):
		interrupt(p);return clip
	if p.side!=-1 and p.side!=int(pose.left_handed):interrupt(p)
	p.side=int(pose.left_handed)
	var hand: Transform3D=pose.right if pose.left_handed else pose.left
	var weapon:=model_pose(pose,w);var local: Vector3=weapon.affine_inverse()*hand.origin
	var hip_hand: Vector3=Hip.frame(pose).affine_inverse()*hand.origin
	var pressed: bool=grip and not p.grip;var released: bool=not grip and p.grip
	var eject_edge: bool=eject and not p.eject;p.grip=grip;p.eject=eject
	# A box cannot be changed with the M249 feed cover still shut.
	if eject_edge and not tube_fed(w) and p.mag and (w!=8 or p.cover>.9) and p.grab!="rack":
		p.mag=false;p.ready=false;clip=0;p.stroke=0.0;p.pulled=false;p.event+=1
	if p.grab=="ammo":
		if released:
			p.carry=0;p.grab="";p.left_pouch=false
		elif grip:
			# A real draw is relative to the hips, even when the grab starts at
			# the far end of the recovery area or the player walks while holding.
			if hip_hand.distance_to(p.anchor)>DRAW_DISTANCE:p.left_pouch=true
			var close: bool=hand.origin.distance_to(weapon*MAG_POINTS[w])<INSERT_RADIUS
			var aligned: bool=hand.basis.y.dot(pose.weapon.basis.y)>.20
			if w==11:aligned=aligned and hand.basis.z.dot(pose.weapon.basis.z)>.20
			if p.left_pouch and close and aligned and now-p.started>=.15 and (w!=8 or p.cover>.9):
				if tube_fed(w):clip=mini(clip+1,mini(capacity,total))
				else:p.mag=true;clip=mini(capacity,total);p.ready=false
				p.carry=0;p.grab="";p.left_pouch=false;p.event+=1
	elif p.grab=="cover":
		if grip:
			var relative:=local-COVER_PIVOT;var initial: Vector3=p.anchor-COVER_PIVOT
			var angle:=wrapf(atan2(relative.y,relative.z)-atan2(initial.y,initial.z),-PI,PI)
			p.cover=clampf(p.base+angle/deg_to_rad(80),0,1)
			if p.cover>.9 and now-p.started<MIN_STROKE_TIME:p.cover=.89
		elif released:
			# Cover seats at either endpoint; a partial lift cannot open the feed tray.
			p.cover=1.0 if p.cover>.8 else 0.0 if p.cover<.2 else p.base
			p.grab="";p.event+=1
	elif p.grab=="rack":
		if grip:
			var travel: float=.105 if w==3 else .10 if w==9 else .065
			p.stroke=clampf((local.z-p.anchor.z)/travel,0,1)
			if p.stroke>.90 and now-p.started>=MIN_STROKE_TIME:p.pulled=true
			if p.pulled and p.stroke<.12 and now-p.started>=MIN_STROKE_TIME*1.5:
				chamber(p,clip);p.grab=""
		elif released:
			if p.pulled and not manual_cycle(w):chamber(p,clip)
			else:p.stroke=0.0;p.pulled=false
			p.grab=""
	elif pressed or (w==3 and p.supported and grip and not p.ready):
		var cover_grip:=weapon*cover_point(p.cover)
		if w==8 and hand.origin.distance_to(cover_grip)<GRAB_RADIUS:
			p.grab="cover";p.base=p.cover;p.anchor=local;p.started=now;p.event+=1
		elif hand.origin.distance_to(weapon*RACK_POINTS[w])<GRAB_RADIUS and p.cover<.05 and (w!=3 or not p.ready):
			p.grab="rack";p.anchor=local;p.started=now;p.stroke=0.0;p.pulled=false;p.event+=1
		elif wants_pouch(w,p,clip,total,capacity) and Hip.recovery_contains(pose,hand.origin):
			p.grab="ammo";p.carry=2 if tube_fed(w) else 1;p.started=now;p.anchor=hip_hand;p.left_pouch=false;p.event+=1
	# A hand already gripping the loaded M3 fore-end can pump after firing
	# without releasing/re-grabbing. Interruptions always clear this latch.
	p.supported=w==3 and grip and p.ready and hand.origin.distance_to(weapon*RACK_POINTS[w])<GRAB_RADIUS
	return clip
