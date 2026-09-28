extends RefCounted
## Pure physical interaction state. The authority supplies validated controller
## poses; this never accepts client-supplied ammunition or completion events.
const PHYSICAL:=1
const MAGAZINE:=2
const CHAMBERED:=4
const RACK_GRIP:=8
const COVER_GRIP:=16
const SLIDE_LOCK:=32
const HK_LOCK:=64
const BELT_SEATED:=128
const BELT_GRIP:=256
const PUMP_HOLD:=512
const MAG_GRIP:=1024
const REMOVED_MAG:=4
const ROW_SIZE:=12
const MAX_FLAGS:=2047
const Motion=preload("res://deathmatch/counterstrike/reload_motion.gd")
const GRAB_RADIUS:=.105
const Hip=preload("res://deathmatch/vr/hip_mount.gd")
const DRAW_DISTANCE:=.12
const INSERT_RADIUS:=.095
const MIN_STROKE_TIME:=.10
const USP_SUPPRESSOR_RADIUS:=.16
const RACK_POINTS=[Vector3.ZERO,Vector3(0,.14,-.04),Vector3(0,.14,-.04),Vector3(0,.055,-.51),Vector3(.079,.101,-.19),Vector3(-.044,.144,-.445),Vector3(.084,.106,-.19),Vector3(0,.142,.055),Vector3(.114,.078,-.29),Vector3(.077,.043,.006),Vector3(0,.15,-.04),Vector3(.09,.106,-.438)]
const MAG_POINTS=[Vector3.ZERO,Vector3(0,-.12,.066),Vector3(0,-.12,.049),Vector3(0,.02,-.235),Vector3(0,.02,-.235),Vector3(0,-.06,-.237),Vector3(0,-.08,-.275),Vector3(0,-.08,-.244),Vector3(-.027,-.13,-.335),Vector3(0,-.09,-.291),Vector3(0,-.14,.058),Vector3(0,.153,-.224)]
const COVER_POINT:=Vector3(0,.23,-.10)
const COVER_PIVOT:=Vector3(0,.145,-.424)
const BOLT_PIVOT:=Vector3(0,.085,-.14)
const AK_RELEASE:=Vector3(0,-.04,-.235)
const AK_BUMP_RADIUS:=.115
const HK_RADIUS:=.18
const HK_SLAP_RADIUS:=.20
const HK_PIVOT:=Vector3(0,.142,-.445)
const HK_ANGLE:=-PI/3
const BELT_PICKUP:=Vector3(-.135,-.015,-.335)
const BELT_TRAY:=Vector3(0,.145,-.335)
static func rack_point(w: int,p: Dictionary) -> Vector3:
	if w==9:return BOLT_PIVOT+Basis(Vector3.BACK,p.get("lift",0.0)*PI/3)*(RACK_POINTS[w]-BOLT_PIVOT)+Vector3.BACK*.10*p.stroke
	if w==5:return hk_transform(p.stroke,p.get("lift",0.0))*RACK_POINTS[w]
	return RACK_POINTS[w]+Vector3.BACK*(.105 if w==3 else .065)*p.stroke+Vector3.UP*.055*p.get("lift",0.0)
static func hk_transform(stroke: float,lift: float) -> Transform3D:
	var rotation:=Basis(Vector3.BACK,HK_ANGLE*lift)
	return Transform3D(rotation,HK_PIVOT-rotation*HK_PIVOT+Vector3.BACK*.065*stroke)
static func cover_point(amount: float) -> Vector3:
	return COVER_PIVOT+Basis(Vector3.RIGHT,-amount*deg_to_rad(80))*(COVER_POINT-COVER_PIVOT)
static func tube_fed(w: int) -> bool:return w in [3,4]
static func removable_by_hand(w: int) -> bool:return w in [5,6,7,8,9,11]
static func mag_direction(w: int) -> Vector3:return Vector3.UP if w==11 else Vector3.DOWN
static func magazine_contact(w: int,cover: float,weapon: Transform3D,hand: Vector3) -> bool:
	return removable_by_hand(w) and (w!=8 or cover>.9) and hand.distance_to(weapon*MAG_POINTS[w])<GRAB_RADIUS
static func insertion_aligned(w: int,pose: Dictionary,hand: Transform3D) -> bool:
	var ammo_basis: Basis=hand.basis*load("res://deathmatch/counterstrike/models.gd").ammo_basis(w)
	return tube_fed(w) or ammo_basis.y.dot(pose.weapon.basis.y)>.10 and (w!=11 or ammo_basis.z.dot(pose.weapon.basis.z)>.10)
static func clear_carry(p: Dictionary):
	p.carry=0;p.carried_rounds=0;p.left_pouch=false
static func handguard_first(w: int,local: Vector3) -> bool:
	if w not in [3,4,5,6,7,8,9,11]:return false
	var anchor: Vector3=load("res://deathmatch/counterstrike/models.gd").support(w)
	return local.distance_to(anchor)<local.distance_to(RACK_POINTS[w])
static func manual_cycle(w: int) -> bool:return w in [3,9]
static func make(clip: int) -> Dictionary:
	return {"mag":true,"ready":clip>0,"locked":clip==0,"cover":0.0,"stroke":0.0,"carry":0,"carried_rounds":0,"removed_depth":0.0,"grab":"","grip":true,"eject":true,"pulled":false,"started":0.0,"anchor":Vector3.ZERO,"base":0.0,"left_pouch":false,"side":-1,"supported":false,"event":0,"weapon":0,"lift":0.0,"bolt_stage":0,"bolt_offset":Vector3.ZERO,"hk_locked":false,"belt":clip>0,"belt_progress":1.0 if clip>0 else 0.0,"pump_hold":false,"pump_stage":0,"motion":{},"gestures":{}}
static func interrupt(p: Dictionary):
	# Loss of tracking, menus and holstering never complete a stroke or insert ammo.
	p.grab="";p.grip=true;p.eject=true;clear_carry(p);p.pulled=false;p.supported=false
	p.braced=false
	p.motion={};p.gestures={};p.pump_hold=false;p.pump_stage=0
	if p.weapon!=9 and not p.hk_locked:p.stroke=0.0
	if not p.belt:p.belt_progress=0.0
static func flags(p: Dictionary) -> int:
	return PHYSICAL|(MAGAZINE if p.mag else 0)|(CHAMBERED if p.ready else 0)|(RACK_GRIP if p.grab in ["rack","pump","hk_release"] else 0)|(COVER_GRIP if p.grab=="cover" else 0)|(SLIDE_LOCK if p.locked else 0)|(HK_LOCK if p.hk_locked else 0)|(BELT_SEATED if p.weapon==8 and p.belt else 0)|(BELT_GRIP if p.grab=="belt" else 0)|(PUMP_HOLD if p.pump_hold else 0)|(MAG_GRIP if p.grab=="magazine" else 0)
static func pouch(pose: Dictionary) -> Transform3D:
	return Hip.pouch(pose)
static func model_pose(pose: Dictionary,w: int) -> Transform3D:
	var art=load("res://deathmatch/art.gd")
	return art.held_transform(pose.weapon,w,art.VR_SCALE,"cs16")
static func usp_suppressor_contact(pose: Dictionary) -> bool:
	if pose.is_empty() or not pose.has("offhand_weapon"):return false
	var hand: Transform3D=pose.right if pose.left_handed else pose.left
	var muzzle: Vector3=load("res://deathmatch/counterstrike/models.gd").muzzle(2)
	return hand.origin.distance_to(model_pose(pose,2)*muzzle)<USP_SUPPRESSOR_RADIUS
static func wants_pouch(w: int,p: Dictionary,clip: int,total: int,capacity: int) -> bool:
	return total>clip and clip<capacity and (tube_fed(w) or not p.mag or w==6)
static func can_fire(p: Dictionary,w: int) -> bool:
	return p.ready and p.cover<.05 and p.grab not in ["rack","cover","belt","pump"] and p.stroke<.05 and p.lift<.05 and not p.hk_locked and not p.pump_hold and (w!=8 or p.mag and p.belt)
static func chamber(p: Dictionary,clip: int):
	p.ready=p.mag and clip>0 and p.cover<.05 and (p.weapon!=8 or p.belt);p.locked=p.mag and clip==0;p.stroke=0.0;p.pulled=false;p.lift=0.0;p.bolt_stage=0;p.hk_locked=false;p.event+=1
static func eject_mag(p: Dictionary):
	# Closed-bolt guns keep the chambered round; the clip count includes it.
	p.mag=false;p.ready=p.ready and p.weapon!=8;p.belt=false;p.belt_progress=0.0;p.pulled=false;p.event+=1
	if p.weapon!=9 and not p.hk_locked:p.stroke=0.0
static func bolt(p: Dictionary,contact: Vector3,clip: int,now: float):
	# Remember where the palm touched the knob; requiring its centre to track
	# the mesh knob exactly made a valid continuous close/lock fail in a headset.
	var local: Vector3=contact-p.bolt_offset
	var base: Vector3=RACK_POINTS[9]-BOLT_PIVOT
	var lever:=local-BOLT_PIVOT
	var lift:=clampf(wrapf(atan2(lever.y,lever.x)-atan2(base.y,base.x),-PI,PI)/(PI/3),0,1)
	if p.bolt_stage==0:
		p.lift=lift
		if lift>.1:p.ready=false
		if lift>.65:p.bolt_stage=1
	if p.bolt_stage in [1,2]:
		p.lift=1.0
		p.bolt_high=maxf(float(p.get("bolt_high",local.y)),local.y)
		if p.bolt_stage==1 and lift<.55:return
		p.stroke=clampf((local.z-RACK_POINTS[9].z)/.10,0,1)
		if p.bolt_stage==1 and p.stroke>.75 and now-p.started>=.06:p.bolt_stage=2
		elif p.bolt_stage==2 and p.stroke<.55:p.bolt_stage=3;p.stroke=0.0
	if p.bolt_stage==3:
		p.lift=lift
		var lowered: bool=lift<.55 or local.y<float(p.get("bolt_high",local.y))-.035
		if lowered and absf(local.z-RACK_POINTS[9].z)<.12 and local.distance_to(RACK_POINTS[9])<.24:chamber(p,clip);p.grab=""
static func sample(p: Dictionary,w: int,clip: int,total: int,capacity: int,pose: Dictionary,grip: bool,eject: bool,now: float,enabled: bool=true,input_time: float=-1.0) -> int:
	p.weapon=w
	if not enabled or pose.is_empty():
		interrupt(p);return clip
	if p.side!=-1 and p.side!=int(pose.left_handed):interrupt(p)
	p.side=int(pose.left_handed)
	var hand: Transform3D=pose.right if pose.left_handed else pose.left
	var weapon:=model_pose(pose,w);var local: Vector3=weapon.affine_inverse()*hand.origin
	var motion:=Motion.sample(p,pose,weapon,hand,now if input_time<0 else input_time)
	# A locked pistol can close with a deliberate sideways flick. It cannot
	# load an absent magazine or bypass an ordinary, unlocked slide rack.
	if w in [1,2,10] and p.locked and p.mag and clip>0 and p.grab.is_empty() and not grip:
		if Motion.side_flick(motion):chamber(p,clip);p.gestures={}
	if not pose.has("offhand_weapon"):
		if w in [1,2,10] and p.grab.is_empty():p.grip=true;p.eject=eject;return clip
		interrupt(p);return clip
	var hip_hand: Vector3=Hip.frame(pose).affine_inverse()*hand.origin
	var pressed: bool=grip and not p.grip;var released: bool=not grip and p.grip
	if not grip:p.braced=false
	var eject_edge: bool=eject and not p.eject;p.grip=grip;p.eject=eject
	# A box cannot be changed with the M249 feed cover still shut.
	if eject_edge and not tube_fed(w) and p.mag and (w!=8 or p.cover>.9) and p.grab not in ["rack","magazine"]:
		eject_mag(p);clip=mini(clip,1) if p.ready else 0
	# A palm can hit the raised latch downward or from the side. A single fresh
	# sweep may cross it between packets; require real hand motion, not gun motion.
	if w==5 and p.hk_locked and p.grab.is_empty() and not grip:
		if Motion.slap(motion,rack_point(w,p),HK_SLAP_RADIUS):
			chamber(p,clip);p.gestures={}
	var pump_requested: bool=w==3 and pose.get("pump",false) and grip and not eject
	if pump_requested and (p.pump_hold or hand.origin.distance_to(weapon*rack_point(w,p))<GRAB_RADIUS):
		if not p.pump_hold:p.pump_hold=true;p.pump_stage=0;p.started=now;p.gestures={}
		# The hand now holds the fore-end, never an orphaned pouch shell.
		clear_carry(p)
		p.grab="pump"
		var travel: float=motion.get("support_step",Vector3.ZERO).z
		if not p.ready and Motion.stroke(p,"pump",travel,motion,1.15,.07):
			if p.pump_stage==0:p.pump_stage=1;p.stroke=1.0;p.base=signf(travel);p.started=now;p.gestures={}
			elif signf(travel)!=p.base and now-p.started>=.08 and now-p.started<.8:
				chamber(p,clip);p.pump_stage=0;p.gestures={}
		if p.pump_stage==1 and now-p.started>=.8:p.pump_stage=0;p.stroke=0.0;p.gestures={}
		return clip
	if p.pump_hold:p.pump_hold=false;p.pump_stage=0;p.grab="";p.stroke=0.0;p.gestures={}
	if p.grab=="magazine":
		if released:p.grab="";clear_carry(p)
		elif p.mag:
			# Measure the draw relative to the gun, using fresh bounded tracking.
			# A normal pull is enough; no flick or high speed is required.
			if not motion.get("valid",false):p.anchor=local;p.started=now
			elif (local-p.anchor).dot(mag_direction(w))*.65>=.055 and now-p.started>=.06:
				var loaded:=clip
				eject_mag(p);clip=mini(clip,1) if p.ready else 0;p.carry=REMOVED_MAG
				p.carried_rounds=loaded-clip;p.removed_depth=(local-p.anchor).dot(mag_direction(w));p.started=now
		elif p.carry==REMOVED_MAG and motion.get("valid",false):
			var depth: float=(local-p.anchor).dot(mag_direction(w))
			p.removed_depth=maxf(p.removed_depth,depth)
			# A distinct inward motion prevents the overlapping grab/insert
			# volumes from immediately reseating a just-extracted magazine.
			if (p.removed_depth-depth)*.65>=.025 and hand.origin.distance_to(weapon*MAG_POINTS[w])<INSERT_RADIUS and insertion_aligned(w,pose,hand) and now-p.started>=.06 and (w!=8 or p.cover>.9):
				clip=mini(clip+int(p.carried_rounds),mini(capacity,total));p.mag=true
				if w==8:p.belt=false;p.belt_progress=0.0
				clear_carry(p);p.grab="";p.event+=1
	elif p.grab=="ammo":
		if released:
			clear_carry(p);p.grab=""
		elif grip:
			# A real draw is relative to the hips, even when the grab starts at
			# the far end of the recovery area or the player walks while holding.
			if hip_hand.distance_to(p.anchor)>DRAW_DISTANCE:p.left_pouch=true
			if w==6 and p.mag and p.left_pouch:
				var forward: float=-motion.get("hand_step",Vector3.ZERO).z
				if forward>0 and Motion.stroke(p,"bump",forward,motion,.6,.035) and Motion.swept(motion,AK_RELEASE,AK_BUMP_RADIUS):
					eject_mag(p);clip=mini(clip,1) if p.ready else 0;p.started=now;p.gestures={}
				# The replacement remains in the offhand; a distinct seating
				# motion after the knock-out is required.
				return clip
			var close: bool=hand.origin.distance_to(weapon*MAG_POINTS[w])<INSERT_RADIUS
			var aligned:=insertion_aligned(w,pose,hand)
			if p.left_pouch and close and aligned and now-p.started>=.15 and (w!=8 or p.cover>.9):
				if tube_fed(w):clip=mini(clip+1,mini(capacity,total))
				else:p.mag=true;clip=mini(capacity,total)
				if w==8:p.belt=false;p.belt_progress=0.0
				clear_carry(p);p.grab="";p.event+=1
	elif p.grab=="hk_release":
		if grip and now-p.started>=MIN_STROKE_TIME:
			if local.z-p.anchor.z>.025 or p.anchor.y-local.y>.025:p.pulled=true
		elif released:
			if p.pulled:chamber(p,clip)
			p.grab=""
	elif p.grab=="belt":
		p.belt_progress=clampf((local-BELT_PICKUP).dot((BELT_TRAY-BELT_PICKUP).normalized())/(BELT_TRAY-BELT_PICKUP).length(),0,1)
		# Catch the leader as it enters the tray, including a fast pass or the
		# release sample. The seated latch owns it from then on, not the hand.
		var entered: bool=hand.origin.distance_to(weapon*BELT_TRAY)<.11 or Motion.swept(motion,BELT_TRAY,.10)
		if entered and p.belt_progress>.55 and now-p.started>=.06:
			p.belt=true;p.belt_progress=1.0;p.grab="";p.carry=0;p.event+=1
		elif released:p.grab="";p.carry=0;p.belt_progress=0.0
	elif p.grab=="cover":
		if grip:
			var relative:=local-COVER_PIVOT;var initial: Vector3=p.anchor-COVER_PIVOT
			var angle:=wrapf(atan2(relative.y,relative.z)-atan2(initial.y,initial.z),-PI,PI)
			p.cover=clampf(p.base+angle/deg_to_rad(80),0,1)
			if p.mag and clip>0 and not p.belt:p.cover=maxf(.82,p.cover)
			if p.cover>.9 and now-p.started<MIN_STROKE_TIME:p.cover=.89
		elif released:
			# Cover seats at either endpoint; a partial lift cannot open the feed tray.
			p.cover=1.0 if p.cover>.8 else 0.0 if p.cover<.2 else p.base
			p.grab="";p.event+=1
	elif p.grab=="rack":
		if grip:
			if w==9:
				bolt(p,local,clip,now);return clip
			var travel: float=.105 if w==3 else .10 if w==9 else .065
			p.stroke=clampf((local.z-p.anchor.z)/travel,0,1)
			if p.stroke>.90 and now-p.started>=MIN_STROKE_TIME:p.pulled=true
			if w==5 and p.pulled:
				p.lift=clampf((local.y-p.anchor.y)/.037,0,1)
				if p.lift>.75:p.hk_locked=true;p.lift=1.0;p.stroke=1.0;p.ready=false
			if p.hk_locked:return clip
			if p.pulled and p.stroke<.12 and now-p.started>=MIN_STROKE_TIME*1.5:
				chamber(p,clip);p.grab=""
		elif released:
			if w==9:bolt(p,local,clip,now)
			elif p.hk_locked:pass # Real notch position survives re-gripping.
			elif p.pulled and not manual_cycle(w):chamber(p,clip)
			else:p.stroke=0.0;p.pulled=false
			p.grab=""
	elif pressed or (w==3 and p.supported and grip and not p.ready):
		var cover_grip:=weapon*cover_point(p.cover)
		var belt_first: bool=w==8 and not p.belt and local.distance_to(BELT_PICKUP)<local.distance_to(MAG_POINTS[w])
		if p.mag and magazine_contact(w,p.cover,weapon,hand.origin) and not belt_first:
			p.grab="magazine";p.anchor=local;p.started=now;p.event+=1
		elif w==5 and p.hk_locked and hand.origin.distance_to(weapon*rack_point(w,p))<HK_RADIUS:
			p.grab="hk_release";p.anchor=local;p.started=now;p.pulled=false
		elif w==8 and p.cover>.9 and p.mag and clip>0 and not p.belt and hand.origin.distance_to(weapon*BELT_PICKUP)<GRAB_RADIUS:
			p.grab="belt";p.carry=3;p.started=now;p.event+=1
		elif w==8 and hand.origin.distance_to(cover_grip)<GRAB_RADIUS:
			p.grab="cover";p.base=p.cover;p.anchor=local;p.started=now;p.event+=1
		elif hand.origin.distance_to(weapon*rack_point(w,p))<GRAB_RADIUS and p.cover<.05 and (w!=3 or not p.ready) and (w!=8 or p.belt) and not p.hk_locked and not (p.ready and handguard_first(w,local)):
			p.grab="rack";p.anchor=local;p.started=now;p.pulled=false;p.event+=1
			if w==9:p.bolt_offset=local-rack_point(w,p);p.bolt_high=rack_point(w,p).y
			else:p.stroke=0.0
		elif pressed and wants_pouch(w,p,clip,total,capacity) and Hip.recovery_contains(pose,hand.origin) and not (tube_fed(w) and hand.origin.distance_to(weapon*load("res://deathmatch/counterstrike/models.gd").support(w))<.14):
			# Continuing a held pump or gripping a low fore-end is not a fresh
			# pouch grab, even when it overlaps the broad hip recovery volume.
			p.grab="ammo";p.carry=2 if tube_fed(w) else 1;p.started=now;p.anchor=hip_hand;p.left_pouch=false;p.event+=1
	# A hand already gripping the loaded M3 fore-end can pump after firing
	# without releasing/re-grabbing. Interruptions always clear this latch.
	p.supported=w==3 and grip and p.ready and hand.origin.distance_to(weapon*RACK_POINTS[w])<GRAB_RADIUS
	return clip
