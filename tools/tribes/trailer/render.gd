extends SceneTree
## Offline replay director. Camera work only; the saved authority supplies every
## movement, projectile, hit, vehicle and flag interaction.
class CleanFrame extends Node:
	var game
	func _process(_delta: float):
		# Avatar and vehicle updates may show their labels after replay ingestion.
		if game.hud:game.hud.hide()
		for label in game.find_children("*","Label3D",true,false):label.hide()
class Director extends Node:
	var game
	var plan: Dictionary
	var shot_index:=-1
	var frame:=0
	var output_frame:=0
	var warmup:=90
	var manifest: Array=[]
	var forward:=Vector3.FORWARD
	var combat_look:=Vector3.FORWARD
	var started:=false
	var ui: Array=[]
	var camera_checks: Dictionary={}
	func next_shot():
		shot_index+=1;frame=0;warmup=60
		camera_checks={"clipped_frames":0,"minimum_clear_fraction":1.0}
		if shot_index>=plan.shots.size():
			FileAccess.open(plan.receipt,FileAccess.WRITE).store_string(JSON.stringify(manifest,"  "))
			print("FILM_DONE ",output_frame," frames");get_tree().quit();return
		var shot: Dictionary=plan.shots[shot_index]
		game.clock=maxf(0,float(shot.start)-2)
		game.demos.seek(maxf(0,float(shot.start)-2));game.demos.paused=false
		game.clock=game.demos.position_seconds
		game.demos.selected_player=int(shot.get("bot",-1000));game.demos.viewpoint="free"
		forward=Vector3.FORWARD;combat_look=Vector3.FORWARD;started=true
		ui=game.find_children("*","Label3D",true,false)
		print("FILM_SHOT ",shot.name," start ",shot.start)
	func _process(_delta: float):
		if not started:next_shot()
		if shot_index>=plan.shots.size():return
		var shot: Dictionary=plan.shots[shot_index]
		game.clock+=1.0/30;game.demos.tick(1.0/30)
		game._update_projectile_visuals(1.0/30)
		game.announcer.clear_audio()
		if game.hud:game.hud.hide()
		if output_frame%15==0:ui=game.find_children("*","Label3D",true,false)
		for label in ui:if is_instance_valid(label):label.hide()
		var camera: Camera3D=game.demos.camera
		camera.fov=float(shot.get("fov",58));camera.far=2000
		var actor=game.fighters.get(int(shot.get("bot",-1000)))
		if actor:
			var center: Vector3=actor.render_position()+Vector3.UP*1.05
			var velocity: Vector3=actor.visual_velocity;velocity.y=0
			if velocity.length()>2:forward=forward.lerp(velocity.normalized(),.16).normalized()
			elif frame==0:forward=-actor.basis.z
			if shot.has("forward"):forward=Vector3(shot.forward[0],0,shot.forward[1]).normalized()
			var side:=forward.cross(Vector3.UP)
			var eye: Vector3=center-forward*5+side*3+Vector3.UP
			var look:=center
			var excluded: Array[RID]=[]
			match str(shot.get("kind","track")):
				"combat", "duel":
					var enemy=game.fighters.get(int(shot.get("enemy",0)))
					var toward: Vector3=-actor.basis.z*10
					if enemy and enemy.alive_state and enemy.render_position().distance_to(center)<100:toward=(enemy.render_position()+Vector3.UP-center).limit_length(24)
					combat_look=combat_look.lerp(toward,.12)
					var flat:=Vector3(combat_look.x,0,combat_look.z).normalized()
					if flat.length()>.1:
						look=center+combat_look*.35
						eye=center-flat*float(shot.get("distance",5))+flat.cross(Vector3.UP)*float(shot.get("side",5))+Vector3.UP*float(shot.get("height",-.2))
						if shot.kind=="duel":
							look=center+combat_look*.5
							eye=look+flat.cross(Vector3.UP)*maxf(6,combat_look.length()*.75)-flat*2+Vector3.UP*float(shot.get("height",.3))
				"track":
					eye=center+forward*float(shot.get("lead",-4))+side*float(shot.get("side",3))+Vector3.UP*float(shot.get("height",.4))
					look=center+forward*float(shot.get("look_forward",.8))
				"orbit":
					var angle:=float(shot.get("angle",0))+frame/30.0*float(shot.get("rate",.12))
					var radius:=float(shot.get("radius",8))
					eye=center+Vector3(cos(angle)*radius,float(shot.get("height",3)),sin(angle)*radius)
				"low":
					eye=center-forward*float(shot.get("distance",5))+side*float(shot.get("side",3))-Vector3.UP*.7
					look=center+forward*1.5
				"vehicle":
					var controller=game.match_mode.tribes.vehicles
					var key:=int(shot.get("vehicle",1))
					if controller.rows.has(key):
						excluded.append(controller.bodies[key].get_rid())
						var row: Dictionary=controller.rows[key]
						var pose: Transform3D=controller.render_frame(key)
						center=pose.origin;forward=-pose.basis.z;side=pose.basis.x
						look=center+Vector3.UP*.7
						eye=center+forward*float(shot.get("distance",13))+side*float(shot.get("side",3))+Vector3.UP*float(shot.get("height",.4))
				"wide":
					var anchor: Array=shot.anchor
					look=Vector3(anchor[0],anchor[1],anchor[2]);center=look
					var angle:=float(shot.get("angle",0))+frame/30.0*.05
					eye=look+Vector3(cos(angle)*float(shot.get("radius",100)),float(shot.get("height",50)),sin(angle)*float(shot.get("radius",100)))
			var space: PhysicsDirectSpaceState3D=game.get_world_3d().direct_space_state
			var obstruction: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(center,eye,1,excluded))
			if not obstruction.is_empty() and warmup==0:
				camera_checks.clipped_frames+=1
				camera_checks.minimum_clear_fraction=minf(camera_checks.minimum_clear_fraction,center.distance_to(obstruction.position)/maxf(.01,center.distance_to(eye)))
			if not obstruction.is_empty():eye=obstruction.position+obstruction.normal*.3
			var floor_hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(eye+Vector3.UP*2,eye-Vector3.UP*.5,1,excluded))
			if not floor_hit.is_empty():eye.y=maxf(eye.y,floor_hit.position.y+.4)
			camera.global_position=eye
			if eye.distance_to(look)>.1:camera.look_at(look)
			game.demos.free_rotation=Vector2(camera.rotation.y,camera.rotation.x)
		if warmup>0:
			warmup-=1
			if warmup==0:
				# Godot captures the boot frame before the deferred scene setup.
				manifest.append({"name":shot.name,"first_frame":Engine.get_frames_drawn(),"frames":roundi(float(shot.duration)*30),"source_start":game.demos.position_seconds,"shot":shot,"camera_checks":camera_checks})
		else:
			frame+=1
			if frame>=roundi(float(shot.duration)*30):next_shot()
		output_frame+=1
func _initialize():call_deferred("run")
func run():
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	root.size=Vector2i(1920,1080);root.content_scale_size=root.size
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	root.size=Vector2i(1920,1080);root.content_scale_size=root.size
	game.voice_enabled=false;game.music.stop()
	if not game.demos.open_demo(plan.demo):push_error(game.demos.message);quit(1);return
	game.set_physics_process(false);game.demos.exit_at_end=false
	game.demos.set_process(false)
	root.msaa_3d=Viewport.MSAA_4X
	game.get_node("DuskSun").shadow_enabled=true
	game.hud.hide();game.menu_open=false
	var director:=Director.new();director.game=game;director.plan=plan;director.process_priority=-40;game.add_child(director)
	var clean:=CleanFrame.new();clean.game=game;clean.process_priority=100;game.add_child(clean)
