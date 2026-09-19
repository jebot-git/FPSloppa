extends SceneTree
const Hits=preload("res://deathmatch/hit_detection.gd")
const Art=preload("res://deathmatch/art.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Lag=preload("res://deathmatch/lag_compensation.gd")
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func ray(x: float,y: float) -> float:
	return Hits.player_fraction(Vector3(x,y,2),Vector3(x,y,-2))
func meshes(node: Node,result: Array) -> void:
	if node.name=="WeaponModel":return
	if node is MeshInstance3D:result.append(node)
	for child in node.get_children():meshes(child,result)
func run() -> void:
	check(is_finite(ray(.48,1.1)),"Outer boxy shoulder is hittable")
	check(not is_finite(ray(.50,1.1)),"Empty space outside shoulder misses")
	check(is_finite(ray(.17,1.64)),"Square top corner of visible head is hittable")
	check(not is_finite(ray(0,1.67)),"Old invisible capsule above the head no longer takes damage")
	check(not is_finite(ray(.22,1.48)),"Empty space beside narrow head misses")
	check(is_finite(ray(.28,.08)),"Boot outer edge is hittable")
	check(not is_finite(ray(0,.08)),"Gap between boots is not filled by a capsule")
	check(not is_finite(Hits.player_fraction(Vector3(2,1.25,.25),Vector3(-2,1.25,.25))),"Empty space behind thin torso misses")
	var side:=Basis(Vector3.UP,PI/2)
	check(is_finite(Hits.player_fraction(side*Vector3(.48,1.1,2),side*Vector3(.48,1.1,-2),1.65,PI/2)),"Box anatomy follows player facing")
	check(not is_finite(Hits.box_fraction(Vector3(.58,.58,2),Vector3(.58,.58,-2),Vector3.ONE*.5,.1)),"Projectile radius does not square off rounded box corners")
	check(is_finite(Hits.box_fraction(Vector3(.56,.56,2),Vector3(.56,.56,-2),Vector3.ONE*.5,.1)),"Projectile clips a corner within its true radius")
	var stage:=Node3D.new();root.add_child(stage)
	for row in [["stand",1.65],["crouch",1.05],["prone",.65]]:
		var avatar=Art.marine(Color("78a7be"));stage.add_child(avatar)
		for i in 90:avatar.animate(1.0/60,Vector3.ZERO,row[0],row[1],true,{},false)
		var visual: Array=[];meshes(avatar,visual)
		var missed:=0;var samples:=0
		for mesh in visual:
			var bounds: AABB=mesh.mesh.get_aabb()
			for x in [-.499,0,.499]:
				for y in [-.499,0,.499]:
					for z in [-.499,0,.499]:
						var p: Vector3=mesh.global_transform*(bounds.get_center()+bounds.size*Vector3(x,y,z))
						samples+=1
						if not is_finite(Hits.player_fraction(p,p,row[1])):missed+=1
		check(missed==0,"Actual "+row[0]+" placeholder mesh: "+str(samples)+" body samples inside damage volumes, missed="+str(missed))
		avatar.free()
	stage.free()
	var history: Array=[{"time":0.0,"positions":{1:{"position":Vector3.ZERO,"serial":1,"yaw":deg_to_rad(170)}}},{"time":.2,"positions":{1:{"position":Vector3.ZERO,"serial":1,"yaw":deg_to_rad(-170)}}}]
	var rewound:=Lag.positions(history,.2,.1,history[1].positions,false,true)
	check(absf(absf(rewound[1])-PI)<.001,"Lag compensation interpolates facing through angle wrap")
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g);g.start_host("Hitbox",0,100,60,true)
	g.bots.free();g.bots=null;g.set_physics_process(false);g.set_process(false)
	for id in g.players:g.fighters[id].position=Fixture.point(15,15);g.players[id].invulnerable=0;g.players[id].armor=0
	g.fighters[-1].position=Fixture.point();g.fighters[-1].rotation.y=0
	for radius in [0.0,.035,.045,.16]:
		var start:=Fixture.point(.48+radius,2)+Vector3.UP*1.1
		check(g._trace(start,start+Vector3.FORWARD*4,1,0,radius).id==-1,"Shared weapon trace reaches shoulder with radius "+str(radius))
	var head: Dictionary=g._trace(Fixture.point(.17,2)+Vector3.UP*1.64,Fixture.point(.17,-2)+Vector3.UP*1.64,1)
	var shoulder: Dictionary=g._trace(Fixture.point(.48,2)+Vector3.UP*1.25,Fixture.point(.48,-2)+Vector3.UP*1.25,1)
	check(head.id==-1 and head.headshot and shoulder.id==-1 and not shoulder.headshot,"Head damage is classified by actual head box, not shoulder height")
	g.players[1].weapon=2;g.players[1].yaw=0;g.players[1].pitch=0;g.players[1].owned=[2];g.players[1].ammo=[20,0,0,0];g.fighters[1].position=Fixture.point(0,3)
	for offhand in [false,true]:
		g.players[1].cooldown=0;g.players[1].offhand_cooldown=0;g.players[1].held=false;g.players[1].offhand_held=false
		var hp: int=g.players[-1].hp;g._fire(1,offhand)
		check(g.players[-1].hp<hp,"Desktop pistol follows centered crosshair, offhand="+str(offhand))
	g.clock=.2;g.history=[{"time":0.0,"positions":g._history_positions()}];g.fighters[-1].rotation.y=PI/2
	var start:=Fixture.point(.48,2)+Vector3.UP*1.1;var end:=start+Vector3.FORWARD*4
	check(g._trace(start,end,1,.2).id==-1 and g._trace(start,end,1).id==0,"Authoritative rewind restores the target's historical facing")
	g.free()
	if OS.get_cmdline_user_args().has("--visual"):await show_visual()
	print("PLAYER_HITBOX_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)

func show_visual() -> void:
	root.size=Vector2i(1500,900)
	var stage:=Node3D.new();root.add_child(stage)
	var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("182129");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.8;stage.add_child(world)
	var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(0,2.3,10);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=7.5;camera.make_current()
	for row in 2:
		for column in 3:
			var height: float=[1.65,1.05,.65][column];var stance: String=["stand","crouch","prone"][column]
			var actor:=Node3D.new();stage.add_child(actor);actor.position=Vector3((column-1)*2.4,2.4 if row==0 else .05,0);actor.rotation.y=0 if row==0 else PI/2
			var avatar=Art.marine(Color("738799"));actor.add_child(avatar);avatar.get_node("Upper/WeaponModel").hide()
			for i in 90:avatar.animate(1.0/60,Vector3.ZERO,stance,height,true,{},false)
			var lines:=ImmediateMesh.new();lines.surface_begin(Mesh.PRIMITIVE_LINES)
			for part in Hits.Body.parts(height):
				for axis in 3:
					for a in [-1,1]:
						for b in [-1,1]:
							var start:=Vector3.ZERO;start[axis]=-1;start[(axis+1)%3]=a;start[(axis+2)%3]=b
							var end:=start;end[axis]=1
							lines.surface_add_vertex(part.pose*(start*part.size*.5));lines.surface_add_vertex(part.pose*(end*part.size*.5))
			lines.surface_end()
			var overlay:=MeshInstance3D.new();overlay.mesh=lines;actor.add_child(overlay)
			var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("79ffaf");material.no_depth_test=true;overlay.material_override=material
			var label:=Label3D.new();label.text=stance.to_upper()+ (" · FRONT" if row==0 else " · SIDE");label.position=actor.position+Vector3(0,1.95,0);label.font_size=32;label.pixel_size=.003;stage.add_child(label)
	for i in 8:await process_frame
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute("res://test-results/player-hitbox")
	root.get_texture().get_image().save_png("res://test-results/player-hitbox/placeholder-bounds.png")
	stage.free()
