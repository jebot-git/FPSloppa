extends Node3D
## Bounded cosmetic effects. No effect body participates in damage or player collision.
const Art=preload("res://deathmatch/art.gd")
var game
var particles: Array=[]
var gibs: Array=[]
var stains: Array=[]
var sounds: Dictionary={}
var voices: Array=[]
var last_hit: Dictionary={}
var last_pain: Dictionary={}
var surface_hits: Dictionary={}
var surface_audio_at:=-10.0
var confirmation: AudioStreamPlayer
var confirmation_at:=-10.0
var steps: Dictionary={}
var enabled:=true
var local_pickup: AudioStreamPlayer
var local_pain: AudioStreamPlayer
var local_pain_at:=-10.0
func setup(arena: Node) -> void: game=arena
func play(kind: String,position_here: Vector3,volume: float=-8.0) -> void:
	if game.headless:return
	game.spatial.play(kind,position_here,volume)
func clear() -> void:
	if game.spatial: game.spatial.clear()
	for child in get_children(): child.queue_free()
	particles.clear();gibs.clear();stains.clear();voices.clear();steps.clear();last_hit.clear()
	local_pickup=null;local_pain=null;local_pain_at=-10
	confirmation=null;confirmation_at=-10;surface_audio_at=-10;surface_hits.clear();last_pain.clear()
func hit(id: int,pos: Vector3,direction: Vector3,amount: int,dead: bool,gibbed: bool,seed_value: int) -> void:
	if game.headless: return
	if game.fighters.has(id):
		var actor=game.fighters[id]
		if actor.avatar and actor.avatar.has_method("hurt") and not dead:actor.avatar.hurt(direction,amount)
		actor.gibbed=gibbed
	if dead or game.clock-float(last_hit.get(id,-10))>.09:
		last_hit[id]=game.clock
		play("gib" if gibbed else "death" if dead else "flesh",pos)
		if not dead and amount>0 and id!=multiplayer.get_unique_id() and game.clock-float(last_pain.get(id,-10))>.4:
			last_pain[id]=game.clock;play("pain",pos,-6)
		if enabled:
			blood(pos,direction,seed_value)
			var fx=game._weapon_visuals()
			for i in 5:fx.particle(pos-direction.normalized()*.035,-direction.normalized()*.9+Vector3(randf_range(-.5,.5),randf_range(.1,.7),randf_range(-.5,.5)),Color(.65,.025,.04,.7),.10,.30,true)
	if enabled and gibbed: burst_gibs(pos,direction,seed_value)
	if id==multiplayer.get_unique_id() and game.is_vr(): game.xr_rig.feedback(.8,.12)
func confirm_hit() -> void:
	# Attacker-only cue, independent of distance. Pellet groups share one click.
	if game.headless or game.quitting or game.clock-confirmation_at<.045:return
	confirmation_at=game.clock
	if not is_instance_valid(confirmation):
		confirmation=AudioStreamPlayer.new();confirmation.bus="ArenaEffects";confirmation.volume_db=-14;confirmation.max_polyphony=3;add_child(confirmation)
	confirmation.stream=game.spatial.choose("hit_confirm");confirmation.play()
func world_hit(pos: Vector3,normal: Vector3,style: int) -> bool:
	if game.headless or style<0 or style>=7 or not pos.is_finite() or not normal.is_finite() or normal.length_squared()<.9:return false
	# Shotgun clusters and overlapping contact/blast messages coalesce locally.
	var key:=Vector3i((pos*5).floor())
	if game.clock-float(surface_hits.get(key,-10))<.07:return false
	if surface_hits.size()>=128:surface_hits.erase(surface_hits.keys()[0])
	surface_hits[key]=game.clock
	var profile=preload("res://deathmatch/effects/surface_marks.gd")
	var energy: bool=style==profile.Style.ENERGY
	var scorch: bool=style==profile.Style.SCORCH
	var bio: bool=style==profile.Style.BIO
	if game.clock-surface_audio_at>=.035:
		surface_audio_at=game.clock
		play("impact_energy" if energy else "impact_heavy" if style in [profile.Style.DENT,profile.Style.SCORCH] else "flesh" if bio else "impact_dust",pos+normal*.04,-10)
	if not enabled:return true
	var fx=game._weapon_visuals();var at:=pos+normal*.035
	var spark_color:=Color("7ccfff") if energy else Color("b0cf50") if bio else Color("ffd78a")
	for i in (10 if energy else 6):
		var velocity:=normal*randf_range(1.2,3.2)+Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1))
		fx.particle(at,velocity,spark_color,.035 if energy else .025,randf_range(.12,.28))
		if i<2 and style in [profile.Style.BULLET,profile.Style.ENERGY,profile.Style.PIN]:fx.streak(PackedVector3Array([at,at+velocity*.065]),spark_color,.006,.12)
	var smoke_color:=Color(.24,.22,.20,.65) if scorch else Color(.52,.48,.42,.60) if not bio else Color(.3,.48,.08,.65)
	for i in (5 if scorch else 3):
		fx.particle(at,normal*randf_range(.25,.7)+Vector3(randf_range(-.2,.2),.25,randf_range(-.2,.2)),smoke_color,.17 if scorch else .14,.55 if scorch else .35,true)
	return true
func pickup(kind: String) -> void:
	if game.headless or game.quitting:return
	if not is_instance_valid(local_pickup):
		local_pickup=AudioStreamPlayer.new();local_pickup.bus="ArenaEffects"
		local_pickup.volume_db=-3;local_pickup.max_polyphony=4;add_child(local_pickup)
	local_pickup.stream=game.spatial.choose(kind);local_pickup.play()
func local_hit() -> void:
	if game.headless or game.clock-local_pain_at<.3: return
	local_pain_at=game.clock
	if not is_instance_valid(local_pain):
		local_pain=AudioStreamPlayer.new()
		local_pain.bus="ArenaEffects"
		local_pain.volume_db=-8
		add_child(local_pain)
	local_pain.stream=game.spatial.choose("pain")
	local_pain.play()

func sparks(pos: Vector3,normal: Vector3) -> void:
	if game.headless or not enabled:return
	particles=particles.filter(is_instance_valid)
	if particles.size()>=12:return
	var p:=CPUParticles3D.new()
	p.position=pos+normal*.025;p.amount=10;p.lifetime=.32;p.one_shot=true;p.explosiveness=1
	p.direction=normal.normalized();p.spread=65;p.initial_velocity_min=1.5;p.initial_velocity_max=4.0
	p.gravity=Vector3(0,-8,0);p.scale_amount_min=.012;p.scale_amount_max=.028
	var mesh:=BoxMesh.new();mesh.size=Vector3(.35,.35,2.5);p.mesh=mesh
	p.material_override=Art.material(Color("ffcb69"),0,3)
	add_child(p);particles.append(p)
	get_tree().create_timer(.5).timeout.connect(p.queue_free)

func blood(pos: Vector3,direction: Vector3,seed_value: int) -> void:
	particles=particles.filter(is_instance_valid)
	if particles.size()>=12: return
	var p:=CPUParticles3D.new()
	p.position=pos
	p.amount=20
	p.lifetime=.55
	p.one_shot=true
	p.explosiveness=1
	p.direction=direction.normalized() if direction.length()>.1 else Vector3.UP
	p.spread=42
	p.initial_velocity_min=1.2
	p.initial_velocity_max=3.8
	p.gravity=Vector3(0,-12,0)
	p.scale_amount_min=.012
	p.scale_amount_max=.06
	var mesh:=BoxMesh.new()
	mesh.size=Vector3.ONE
	p.mesh=mesh
	p.material_override=Art.material(Color("ac1722"),0,.25)
	add_child(p)
	particles.append(p)
	get_tree().create_timer(.8).timeout.connect(p.queue_free)
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value
	for d in [direction.normalized()*3+Vector3(0,-1,0),Vector3(rng.randf_range(-1,1),-4,rng.randf_range(-1,1))]:
		var query:=PhysicsRayQueryParameters3D.create(pos,pos+d,1)
		var hit_data:=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit_data.is_empty(): stain(hit_data.position,hit_data.normal,rng)
func stain(pos: Vector3,normal: Vector3,rng: RandomNumberGenerator) -> void:
	stains=stains.filter(is_instance_valid)
	if stains.size()>=48: stains.pop_front().queue_free()
	var decal:=Decal.new()
	decal.texture_albedo=load("res://deathmatch/effects/blood.svg")
	var size_here:=rng.randf_range(.25,.7)
	decal.size=Vector3(size_here,.10,size_here)
	decal.modulate=Color("681018")
	decal.cull_mask=1
	decal.position=pos+normal*.025
	decal.basis=Basis(Quaternion(Vector3.UP,normal))*Basis(Vector3.UP,rng.randf()*TAU)
	add_child(decal)
	stains.append(decal)
	var tween:=decal.create_tween()
	tween.tween_interval(18)
	tween.tween_property(decal,"modulate:a",0.0,3)
	tween.tween_callback(decal.queue_free)
func burst_gibs(pos: Vector3,direction: Vector3,seed_value: int) -> void:
	gibs=gibs.filter(is_instance_valid)
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value
	for i in range(7):
		if gibs.size()>=32: gibs.pop_front().queue_free()
		var body:=RigidBody3D.new()
		body.collision_layer=0
		body.collision_mask=1
		body.mass=.4
		body.position=pos+Vector3(rng.randf_range(-.2,.2),rng.randf_range(-.3,.3),rng.randf_range(-.2,.2))
		var shape:=CollisionShape3D.new()
		var sphere:=SphereShape3D.new()
		sphere.radius=.09
		shape.shape=sphere
		body.add_child(shape)
		var size_here:=Vector3(rng.randf_range(.09,.2),rng.randf_range(.08,.18),rng.randf_range(.12,.28))
		if i==0:
			var head_piece:=MeshInstance3D.new()
			var head_mesh:=SphereMesh.new()
			head_mesh.radius=.13
			head_mesh.height=.25
			head_mesh.radial_segments=8
			head_mesh.rings=4
			head_piece.mesh=head_mesh
			head_piece.material_override=Art.material(Color("a25d4d"))
			body.add_child(head_piece)
		else: Art.box(body,Vector3.ZERO,size_here,Art.material(Color("a12c28") if i%2 else Color("541016")))
		if i%3==0: Art.box(body,Vector3(0,.055,0),size_here*.45,Art.material(Color("dfbca0")))
		add_child(body)
		body.linear_velocity=direction.normalized()*3+Vector3(rng.randf_range(-3,3),rng.randf_range(3,6),rng.randf_range(-3,3))
		body.angular_velocity=Vector3(rng.randf_range(-6,6),rng.randf_range(-6,6),rng.randf_range(-6,6))
		gibs.append(body)
		var reference: WeakRef=weakref(body)
		get_tree().create_timer(10).timeout.connect(func():
			var piece=reference.get_ref()
			if is_instance_valid(piece):gibs.erase(piece);piece.queue_free())
func _process(delta: float) -> void:
	if not game or not game.active or game.headless: return
	for id in game.fighters:
		var actor=game.fighters[id]
		if not game.players[id].dead and actor.visual_velocity.length()>1:
			steps[id]=float(steps.get(id,0))+delta
			if steps[id]>(.3 if actor.visual_velocity.length()>6 else .48):
				steps[id]=0.0
				var query:=PhysicsRayQueryParameters3D.create(actor.position+Vector3.UP*.15,actor.position-Vector3.UP*.25,1)
				if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): play("step",actor.position,-19)
