extends RefCounted
## Armour / energy-pack movement study. Godot metres, Y up.
## Shared by authority and prediction; see docs/TRIBES-MOVEMENT.md for provenance
## and the deliberate capsule/contact differences from the original engine.
const Armour=preload("res://deathmatch/movement/tribes_armour.gd")
const MAX_ENERGY:=60.0
const RECHARGE:=11.0 # Base armour 8 + equipped energy pack 3 per second.
const DRAIN:=25.0
const RESTART_ENERGY:=3.0
const GRAVITY:=20.0
const THRUST:=236.0/9.0
const WALK_SPEED:=11.0
const WALK_ACCEL:=40.0
const JUMP_SPEED:=75.0/9.0
const SIDE_SHARE:=.8
const SIDE_SPEED:=22.0
const CONTACT_GRACE:=.256
const MAX_STEP:=1.0/120.0

static func fresh(armour: String="light",pack: String="energy") -> Dictionary:
	return {"armour":armour,"pack":pack,"pack_on":false,"energy":Armour.definition(armour).energy,"jetting":false,"skiing":false,"grounded":false,"normal":Vector3.UP,"airtime":CONTACT_GRACE,"exhausted":false,"time":0.0}

static func valid_state(s: Variant) -> bool:
	if not s is Dictionary or s.size()!=11 or not Armour.CLASSES.has(s.get("armour")):return false
	if not preload("res://deathmatch/tribes/arsenal.gd").PACKS.has(s.get("pack")) or not s.get("pack_on") is bool:return false
	for key in ["jetting","skiing","grounded","exhausted"]:
		if not s.get(key) is bool:return false
	for key in ["energy","airtime","time"]:
		var value=s.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or value<0:return false
	return s.energy<=Armour.definition(s.armour).energy and s.airtime<=CONTACT_GRACE and s.get("normal") is Vector3 and s.normal.is_finite() and absf(s.normal.length_squared()-1.0)<.01

static func energy_tick(s: Dictionary,held: bool,delta: float) -> float:
	# Recharge continues during the burn. Empty jets need a small reserve before
	# restarting, preventing an almost-empty pack from providing full free thrust.
	var profile:=Armour.definition(s.armour)
	if s.energy>=RESTART_ENERGY:s.exhausted=false
	var recharge: float=8.0+(3.0 if s.pack=="energy" else 0.0)-(9.0 if s.pack=="shield" and s.pack_on else 10.0 if s.pack=="jammer" and s.pack_on else 0.0)
	var burn: float=minf(delta,float(s.energy)/(profile.drain-recharge)) if held and not s.exhausted else 0.0
	s.energy=clampf(s.energy+recharge*delta-profile.drain*burn,0,profile.energy)
	s.jetting=burn>0
	if held and burn>0 and burn<delta-.000001:s.exhausted=true
	if s.energy<=.00001:s.energy=0.0;s.exhausted=true;s.pack_on=false
	return burn

static func jet_acceleration(velocity: Vector3,wish: Vector3,airtime: float,armour: String="light") -> Vector3:
	var profile:=Armour.definition(armour)
	var side:=0.0
	if airtime>=CONTACT_GRACE and not wish.is_zero_approx():
		side=clampf(1.0-velocity.dot(wish.normalized())/profile.side_speed,0,SIDE_SHARE)*wish.length()
	return Vector3.UP*profile.thrust*(1.0-side)+wish.normalized()*profile.thrust*side

static func support(actor) -> Vector3:
	var contact:=KinematicCollision3D.new()
	if actor.test_move(actor.global_transform,Vector3.DOWN*.045,contact,.001,true,4):
		for i in contact.get_collision_count():
			var normal:=contact.get_normal(i)
			if normal.y>.2 and actor.velocity.dot(normal)<.35:return normal
	return Vector3.ZERO

static func simulate(actor,wish: Vector3,slow: bool,delta: float,jump: bool) -> void:
	var s: Dictionary=actor.tribes_state
	var profile:=Armour.definition(s.armour)
	var blocked: bool=actor.tribes_blocked or actor.frozen or actor.spectator
	if blocked:wish=Vector3.ZERO
	var ski: bool=actor.ski_held and not blocked and not actor.in_water
	s.skiing=ski;s.jetting=false
	actor.travel_path=[actor.position]
	actor.blast_velocity=Vector2.ZERO # Blast impulses are already in velocity.
	actor.stepped_last_frame=false;actor.floor_grace=0;actor.jump_queued=false
	var jump_edge: bool=jump and not actor.jump_held and not blocked and actor.stance!="prone"
	actor.jump_held=jump
	var steps:=clampi(ceili(delta/MAX_STEP),1,24)
	var dt:=delta/steps
	for step in steps:
		var normal:=support(actor)
		var grounded:=not normal.is_zero_approx()
		if grounded:s.normal=normal;s.airtime=0.0
		else:s.airtime=minf(CONTACT_GRACE,s.airtime+dt)
		if jump_edge and (grounded or s.airtime<CONTACT_GRACE) and not actor.in_water:
			actor.velocity+=Vector3.UP*profile.jump*maxf(0,s.normal.y)
			var away: float=maxf(0,s.normal.dot(wish))
			actor.velocity+=wish*profile.jump*away
			grounded=false;s.airtime=CONTACT_GRACE;jump_edge=false
		var burn:=energy_tick(s,actor.jet_held and not blocked and not actor.in_water and actor.stance!="prone",dt)
		var acceleration:=Vector3.DOWN*GRAVITY
		if burn>0:acceleration+=jet_acceleration(actor.velocity,wish,s.airtime,s.armour)*(burn/dt)
		if grounded and not ski:
			var target: Vector3=wish.slide(normal)*profile.walk*actor.stance_speed()*(.55 if slow else 1.0)
			var tangent: Vector3=actor.velocity.slide(normal).move_toward(target,profile.accel*dt)
			actor.velocity=tangent+normal*maxf(0,actor.velocity.dot(normal))
		# There is no free air steering. Directional jets provide air control.
		if actor.in_water:
			actor.velocity=actor.velocity.move_toward(wish*profile.walk*.5,profile.accel*dt)
			if jump:actor.velocity.y=5.5
			acceleration*=.15
		actor.velocity+=acceleration*dt
		if grounded and actor.velocity.dot(normal)<0:actor.velocity=actor.velocity.slide(normal)
		var travel: Vector3=actor.velocity*dt
		# Walking retains stair access; skiing never converts stair snap to lift.
		if grounded and not ski and not s.jetting and actor.velocity.length()<profile.walk+1 and actor.step_up(travel,.42):
			actor.travel_path.append(actor.position)
		else:
			for contact_index in 6:
				var collision: KinematicCollision3D=actor.move_and_collide(travel,false,.001)
				actor.travel_path.append(actor.position)
				if collision==null:break
				var n:=collision.get_normal()
				if n.y>.2:s.normal=n;s.airtime=0.0
				# Project only incoming velocity; never normalize it back to the
				# previous speed (that would generate energy at walls and seams).
				if actor.velocity.dot(n)<0:actor.velocity=actor.velocity.slide(n)
				travel=collision.get_remainder().slide(n)
				if travel.length_squared()<.00000001:break
		s.grounded=not support(actor).is_zero_approx()
		s.time+=dt
	actor.visual_grounded=s.grounded

static func reconcile(actor,authority: Dictionary,reference: Dictionary={}) -> void:
	if not valid_state(authority):return
	if reference.is_empty() or authority.armour!=actor.tribes_state.armour or authority.pack!=actor.tribes_state.pack:actor.tribes_state=authority.duplicate(true);return
	# Preserve newer held input/contact decisions while correcting the energy
	# at the acknowledged command. Server energy is never read from client input.
	var s: Dictionary=actor.tribes_state
	s.pack_on=authority.pack_on
	s.energy=clampf(s.energy+float(authority.energy)-float(reference.get("energy",authority.energy)),0,Armour.definition(s.armour).energy)
	if s.energy<=0:s.exhausted=true;s.jetting=false
	elif s.energy>=RESTART_ENERGY:s.exhausted=false

static func status(actor) -> String:
	var s: Dictionary=actor.tribes_state
	return "%s · %d km/h · %s"%[s.armour.to_upper(),roundi(actor.velocity.length()*3.6),"JETS" if s.jetting else "RECHARGING" if s.exhausted else "SKI" if s.skiing else "WALK"]
