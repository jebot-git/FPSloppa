extends SceneTree
const Art=preload('res://deathmatch/art.gd')
var models:Array=[]
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1920,1200);root.content_scale_size=root.size
	var stage:=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color('19222c');env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.7;stage.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-35,0);light.light_energy=1.1;stage.add_child(light)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(20,140,0);fill.light_energy=.45;stage.add_child(fill)
	var camera:=Camera3D.new();camera.position=Vector3(0,0,10);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=7.8;stage.add_child(camera)
	var pairs=[['ut99',1],['ut99',7],['ut99',6],['ut99',5],['tribes',1],['tribes',3],['tribes',4],['tribes',7],['doom',4],['cs16',1],['cs16',9],['cs16',8]]
	for i in pairs.size():
		var model:=Art.weapon(pairs[i][1],2,pairs[i][0]);stage.add_child(model)
		model.position=Vector3((i%4-1.5)*1.87,1.3-(i/4)*1.45,0);model.rotation_degrees=Vector3(12,70,-6);model.scale=Vector3.ONE*1.45;model.process_mode=Node.PROCESS_MODE_DISABLED
		models.append(model)
		var label:=Label3D.new();label.text=pairs[i][0].to_upper()+' '+str(pairs[i][1]);label.font_size=28;label.pixel_size=.0025;label.position=model.position+Vector3(0,-.45,.9);stage.add_child(label)
	DirAccess.make_dir_recursive_absolute('/tmp/fps-weapon-mechanism-frames')
	for frame in 150:
		for i in models.size():
			var model:Node3D=models[i];var action=model.get_node('WeaponMechanism')
			if i==1:Art.charge(model,frame/20.0 if frame<20 else 0)
			if frame in [20,85] or i in [3,4,11] and frame in [25,30,35,40,45,50,55]:
				Art.fire(model,pairs[i][1],pairs[i][0],.7)
				if pairs[i][0]=='cs16':preload('res://deathmatch/counterstrike/models.gd').fire(model)
			action._process(1./30)
			if model.has_node('ChamberAction'):model.get_node('ChamberAction')._process(1./30)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png('/tmp/fps-weapon-mechanism-frames/%04d.png'%frame)
	stage.free();await process_frame;print('WEAPON_MECHANISM_PREVIEW_COMPLETE');quit()
