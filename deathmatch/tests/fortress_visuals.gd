extends SceneTree
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value:failures.append(label)
func _initialize():call_deferred("run")
func shot(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/"+name+".png")
func run() -> void:
	root.size=Vector2i(1600,900)
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false);game.hud.hide()
	for child in game.get_node("Map").get_children():child.free()
	game.Art.box(game,Vector3(0,-.5,0),Vector3(40,1,24),game.Art.material(Color("343944")))
	var light:=DirectionalLight3D.new();game.add_child(light);light.rotation_degrees=Vector3(-55,-30,0);light.light_energy=1.5
	game.match_mode.kind="tf";game.active=true;game.spawn_points=[Vector3.ZERO,Vector3(0,0,-10)];game.match_mode.reset()
	var library=game.avatars.library;var hash_d: String=FileAccess.get_sha256(library.Paths.folder("vrm")+"sample_d.vrm")
	var hash_f: String=FileAccess.get_sha256(library.Paths.folder("vrm")+"sample_f.vrm")
	var tf=game.match_mode.fortress;var ids: Array=[]
	for index in tf.CLASSES.size():
		var id: int=-10-index;ids.append(id);game._add_player(id,"Player "+str(index+1));game.players[id].tf_class=tf.CLASSES.keys()[index];game.players[id].team=0 if index%2==0 else 1
		var actor=game.fighters[id];actor.position=Vector3((index-4)*3.2,0,0);actor.show_alive(true,false)
		actor.set_avatar(library.create_avatar(hash_d),hash_d);actor.visual_weapon=tf.definition(id).weapon
		game.avatars.choices[id]={"hash":hash_d,"size":library.entries[hash_d].size}
	game._add_player(1,"Observer");game.players[1].team=0;game.fighters[1].position=Vector3(100,0,0)
	var camera: Camera3D=game.get_node("Overview");camera.make_current();camera.position=Vector3(0,2.4,23);camera.look_at(Vector3(0,1.1,0))
	for i in 15:await process_frame
	tf.draw()
	for id in ids:check(game.fighters[id].class_badge.text.contains(tf.definition(id).name),"Model-independent class badge "+tf.definition(id).name)
	await shot("tf-class-badges")
	camera.position=Vector3(9.6,2.2,6);camera.fov=55;camera.look_at(Vector3(9.6,1.2,0));await shot("tf-class-badges-close")
	var spy: int=ids[7];var target: int=ids[8];game.players[spy].team=0;game.players[target].team=1;game.avatars.choices[target]={"hash":hash_f,"size":library.entries[hash_f].size}
	tf.cooldowns[spy]=0;check(tf.action(spy),"Default Spy disguise enabled")
	for i in 50:tf.draw();await process_frame
	var actor=game.fighters[spy]
	check(actor.avatar_hash==hash_f,"Spy display swaps to enemy VRM")
	check(actor.avatar!=game.fighters[target].avatar,"Disguise uses independent skeleton/animation instance")
	tf.spy_invisibility=true;tf.cooldowns[spy]=0;game.players[spy].ammo[3]=50;tf.action(spy)
	for i in 50:tf.draw();await process_frame
	check(actor.cloak_active and actor.class_badge.visible,"Teammates retain SPY badge and ghost model")
	check(actor.cloak_meshes.size()>0,"Cloak covers actual VRM and weapon meshes")
	await shot("tf-spy-friendly-cloak")
	game.players[1].team=1
	for i in 90:tf.draw();await process_frame
	check(actor.cloak_visibility<.01 and not actor.label.visible and not actor.class_badge.visible,"Enemy cloak hides mesh, name, badge and shadow")
	tf.revealed(spy)
	for i in 15:tf.draw();await process_frame
	check(actor.avatar_hash==hash_d and not actor.cloak_active,"Reveal restores original VRM and materials")
	await test_ability_effects(game,camera)
	print("TF_VISUAL_RESULT ",JSON.stringify(failures));game.free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)

func test_ability_effects(game,camera: Camera3D) -> void:
	for actor in game.fighters.values():actor.hide()
	camera.position=Vector3(0,8,15);camera.fov=60;camera.look_at(Vector3(0,0,0))
	var kinds=preload("res://deathmatch/modes/fortress_fx.gd").KINDS
	for i in kinds.size():
		var pos:=Vector3((i%4-1.5)*4,1,(int(i/4)-1)*4)
		var label:=Label3D.new();label.text=kinds[i].to_upper();label.font_size=40;label.pixel_size=.007;label.position=pos+Vector3(0,-.8,1);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;game.add_child(label)
	for i in 12:await process_frame
	for i in kinds.size():
		var pos:=Vector3((i%4-1.5)*4,1,(int(i/4)-1)*4)
		game._ability_fx(kinds[i],pos,pos+Vector3(1.4,.2,0),i%2)
	check(game.ability_effects.bursts.size()==kinds.size(),"Every supported ability creates its graphical effect")
	await shot("tf-ability-effects")
	await create_timer(.8).timeout
	check(game.ability_effects.bursts.is_empty(),"All ability effects expire and release their nodes")
	for i in 90:game._ability_fx("heal",Vector3.ZERO,Vector3.RIGHT,0)
	check(game.ability_effects.bursts.size()==64,"Simultaneous effects remain bounded at 64")
	await create_timer(.8).timeout
	check(game.ability_effects.bursts.is_empty(),"Capped effects clean up without stale references")
