extends "res://deathmatch/tests/cs16.gd"
const Body=preload("res://deathmatch/avatars/hit_body.gd")
const Arsenal=preload("res://deathmatch/counterstrike/arsenal.gd")
var measurements: Array=[]
func prepare(w: int):
	reset(w);g.armory.table=Arsenal.table();g.history.clear()
	for id in g.players:
		g.players[id].crouch=false;g.players[id].prone=false
		g.fighters[id].update_height(1.65,true);g.fighters[id].rotation=Vector3.ZERO
		g.fighters[id].xr_pose={};g.fighters[id].in_water=false;g.fighters[id].stepped_last_frame=true
	g.players[1].weapon_zoom=true
func aim_at(point: Vector3):
	var direction: Vector3=(point-g._weapon_transform(1).origin).normalized()
	g.players[1].yaw=atan2(-direction.x,-direction.z);g.players[1].pitch=asin(direction.y)
func shot_angles(w: int,stance: String,vr: bool=false,support: bool=true,moving: bool=false,air: bool=false,water: bool=false) -> Vector2:
	prepare(w)
	for id in g.players:
		if id!=1:g.players[id].dead=true
	var s: Dictionary=g.players[1];var actor=g.fighters[1]
	s.crouch=stance=="crouch";s.prone=stance=="prone"
	if vr:
		s.vr_device=true;s.xr=Poses.neutral()
		s.xr.height=1.05 if s.crouch else .65 if s.prone else 1.65
		s.xr.head.origin.y=s.xr.height-.1
		s.xr.weapon.origin=Vector3(.2,s.xr.height-.25,-.3);s.xr.right=s.xr.weapon
		s.xr.offhand_weapon=s.xr.left;s.reload_grip=support;cs.physical(1).braced=support
	g._update_crouch(1,s.xr);actor.stepped_last_frame=not air;actor.in_water=water
	actor.velocity=Vector3(3,0,0) if moving else Vector3.ZERO
	var basis: Basis=g._weapon_transform(1).basis
	g.demos.events.clear();g.demos.recording=true;seed(9016)
	check(cs.shoot(1),"CS shot accepted: "+str([w,stance,vr,support,moving,air,water]))
	g.demos.recording=false
	var angles:=Vector2.ZERO
	for event in g.demos.events:
		if event[0]!="_impacts":continue
		for end in event[1][1]:
			var ray: Vector3=basis.inverse()*(end-event[1][0])
			angles.x=maxf(angles.x,absf(atan2(ray.x,-ray.z)))
			angles.y=maxf(angles.y,absf(atan2(ray.y,-ray.z)))
	return angles
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
	g.start_host("CS damage and accuracy",0,100,60,true,"dm","cs16");g.bots.free();g.bots=null
	g.set_process(false);g.set_physics_process(false);cs=g.variant_combat.cs
	await physics_frame;await physics_frame
	# Remove random spread only for damage isolation. Hits still traverse the
	# real shot, trace, head-volume, falloff, armor and health paths.
	for w in range(1,12):
		for suppressed in ([false,true] if w in [2,7] else [false]):
			for height in [1.65,1.05,.65]:
				for head in [false,true]:
					# View prone targets from the side: the torso occludes a rear head shot.
					prepare(w);g.fighters[-1].update_height(height,true)
					g.fighters[-1].position=Fixture.point(0,-3);g.fighters[-1].rotation.y=PI/2 if height<.8 else 0.0
					g.armory.table[w].spread=0.0;g.armory.table[w].vertical=0.0
					if suppressed:
						g.armory.table[w].suppressor.spread=0.0;g.armory.table[w].suppressor.vertical=0.0;cs.state(1).modes[w]=true
					var center: Vector3=Body.parts(height)[1 if head else 0].pose.origin
					aim_at(g.fighters[-1].global_transform*center)
					var start: Vector3=g._shot_solution(1).origin
					var direction: Vector3=-g._weapon_transform(1).basis.z
					var hit: Dictionary=g._trace(start,start+direction*200,1)
					var label: String=Arsenal.NAMES[w]+str([suppressed,height,head])
					check(hit.id==-1 and hit.headshot==head,"Head/body trace classification "+label)
					var base: int=(30 if w==2 else 33) if suppressed else Arsenal.VALUES[w][1]
					var range_scale: float=.95 if suppressed and w==7 else Arsenal.VALUES[w][5]
					var per_pellet:=maxi(1,roundi(base*(4 if head else 1)*pow(range_scale,start.distance_to(hit.position)/12.7)))
					var expected: int=per_pellet*(9 if w==3 else 6 if w==4 else 1)
					check(cs.shoot(1) and 2000-g.players[-1].hp==expected,"Actual health damage = range-adjusted "+("4x head" if head else "1x body")+" "+label)
					measurements.append({"weapon":Arsenal.NAMES[w],"suppressed":suppressed,"target_height":height,"head":head,"damage":2000-g.players[-1].hp,"expected":expected})
	# DE intentionally retains the shared armor tiers: vest absorbs 1/3,
	# vest+helmet 1/2, including head hits; absorption cannot exceed armor left.
	for tier in [0,1,2]:
		for armor in ([0] if tier==0 else [100,5]):
			prepare(6);g.match_mode.kind="de";g.match_mode.defusal.phase="live"
			g.players[-1].armor=armor;g.players[-1].tier=tier;g.match_mode.defusal.account(-1).helmet=tier==2
			g.armory.table[6].spread=0.0;g.armory.table[6].vertical=0.0
			aim_at(g.fighters[-1].position+Vector3(0,1.48,0))
			var start: Vector3=g._shot_solution(1).origin
			var hit: Dictionary=g._trace(start,start-g._weapon_transform(1).basis.z*200,1)
			var raw:=roundi(144*pow(.98,start.distance_to(hit.position)/12.7))
			var saved:=mini(armor,int(raw/(2.0 if tier==2 else 3.0)))
			check(cs.shoot(1) and g.players[-1].hp==2000-raw+saved and g.players[-1].armor==armor-saved,"Head multiplier precedes shared DE armor, tier/remaining="+str([tier,armor]))
	# Measure real emitted rays with identical RNG, without changing spread.
	for w in range(1,12):
		var standing:=shot_angles(w,"stand")
		for stance in ["crouch","prone"]:
			var ratio:=.75 if stance=="crouch" else .45
			var current:=shot_angles(w,stance)
			check(current.distance_to(standing*ratio)<.00004,"Actual horizontal/vertical spread scales by "+str(ratio)+" for "+Arsenal.NAMES[w])
	for vr in [false,true]:
		for moving in [false,true]:
			var standing:=shot_angles(6,"stand",vr,true,moving)
			for stance in ["crouch","prone"]:
				var ratio:=.75 if stance=="crouch" else .45
				check(shot_angles(6,stance,vr,true,moving).distance_to(standing*ratio)<.00004,"Stance combines with motion/VR spread "+str([stance,vr,moving]))
	for stance in ["stand","crouch","prone"]:
		check(shot_angles(6,stance,true,false).distance_to(shot_angles(6,stance,true,true)*2)<.00004,"CS rifle one-hand penalty combines with "+stance)
		for w in [1,2,10]:check(shot_angles(w,stance,true,false).distance_to(shot_angles(w,stance,true,true))<.00004,"Pistol remains exempt from one-hand penalty "+str([w,stance]))
	for condition in ["air","water"]:
		var standing:=shot_angles(6,"stand",false,true,false,condition=="air",condition=="water")
		for stance in ["crouch","prone"]:
			check(shot_angles(6,stance,false,true,false,condition=="air",condition=="water").distance_to(standing)<.00004,"No "+stance+" accuracy bonus in "+condition)
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty(),"damage_samples":measurements}
	FileAccess.open("res://test-results/cs16/snip/accuracy.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CS16_ACCURACY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
