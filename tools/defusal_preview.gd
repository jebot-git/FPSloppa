extends SceneTree
const Bomb=preload("res://deathmatch/pickups/bomb_model.gd")
var g
func _initialize():run.call_deferred()
func capture(name: String):
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/defusal/"+name+".png")
func run():
	Engine.max_fps=60;root.size=Vector2i(1440,1000)
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("Defusal preview",0,20,10,true,"de");g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	await physics_frame;await physics_frame
	var de=g.match_mode.defusal;de.tick(0);de.credit(1,7000);g.menu_open=false;g.hud.show_menu(false)
	var camera:=Camera3D.new();g.add_child(camera);camera.fov=70;camera.near=.035;camera.make_current()
	camera.position=de.sites[0]+Vector3(0,1.3,2.0);camera.look_at(de.sites[0]+Vector3.UP*.6)
	de.draw();de.panel.toggle();await capture("buy-categories")
	de.panel.select(201);de.panel.hover=0;de.panel.refresh();await capture("buy-weapons")
	de.panel.close();de.phase="live";de.held=true;de.carrier=1
	g.players[1].yaw=0.0;g.players[1].pitch=0.0
	var wall: Dictionary=de.ray_surface(de.sites[0]+Vector3.UP,de.sites[0]+Vector3.UP+Vector3.FORWARD*5)
	g.fighters[1].position=wall.position+Vector3(0,-1,.8)
	var placed: Dictionary=de.placement(1)
	de.carrier=0;de.held=false;de.bomb_position=placed.pose.origin;de.bomb_basis=placed.pose.basis
	de.planted=true;de.planted_site=0;de.fuse_end=g.clock+32;de.defuse_index=3;de.cut_mask=0
	camera.position=de.bomb_position+Vector3(.30,.18,.68);camera.look_at(de.bomb_position+Vector3(0,.015,0))
	for layer in g.find_children("*","CanvasLayer",true,false):layer.hide()
	de.draw()
	var cutters:=Bomb.cutters();g.add_child(cutters);cutters.position=de.bomb_position+Vector3(.26,-.02,.18);cutters.rotation_degrees=Vector3(75,-10,15)
	await capture("bomb-keypad-cutters")
	cutters.hide();camera.position=de.bomb_position+Vector3(1,1,2.5);camera.look_at(de.bomb_position);await capture("site-a")
	de.carrier=1;de.planted=false;g.fighters[1].position=de.sites[1]+Vector3(0,0,.8)
	placed=de.placement(1);de.carrier=0;de.planted=true;de.planted_site=1;de.bomb_position=placed.pose.origin;de.bomb_basis=placed.pose.basis;de.draw()
	camera.position=de.bomb_position+Vector3(.32,.75,.62);camera.look_at(de.bomb_position);await capture("site-b")
	de.planted=false;de.carrier=-1;de.held=false;g.players[-1].yaw=0.0;g.fighters[-1].position=de.sites[1];g.fighters[-1].target=de.sites[1];g.fighters[-1].rotation.y=0
	g.fighters[-1].show_alive(true,false);g.fighters[-1]._process(.016);de.draw()
	camera.position=de.sites[1]+Vector3(.7,1.6,-1.6);camera.look_at(de.sites[1]+Vector3.UP*1.15);await capture("chest-carrier")
	print("DEFUSAL_RENDER_RESULT PASS");g.disconnect_game();g.queue_free()
	for i in 8:await process_frame
	quit()
