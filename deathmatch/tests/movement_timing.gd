extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
class Driver extends Node:
	var actor
	var ticks:=0
	var elapsed:=0.0
	var distance:=0.0
	func _physics_process(delta: float) -> void:
		var before: Vector3=actor.position
		actor.simulate(Vector2.UP,0,false,delta)
		if ticks>=60 and ticks<180:
			elapsed+=delta;distance+=Vector2(actor.position.x-before.x,actor.position.z-before.z).length()
		ticks+=1
func _initialize():call_deferred("run")
func run() -> void:
	var failed:=false
	for rates in [[30,60],[60,60],[72,60],[90,60],[120,60],[144,60],[90,90],[144,120]]:
		Engine.max_fps=rates[0];Engine.physics_ticks_per_second=rates[1]
		var world:=Node3D.new();root.add_child(world);Fixture.box(world,Vector3(0,-.5,0),Vector3(20,1,200))
		var actor=preload("res://deathmatch/fighter.gd").new();actor.setup(1,"Delta",Color.WHITE);actor.quake_movement=true;world.add_child(actor);actor.position.y=.01
		var driver:=Driver.new();driver.actor=actor;world.add_child(driver)
		while driver.ticks<180:await process_frame
		var speed:=driver.distance/driver.elapsed
		var passed:=absf(speed-9.4)<.015
		print("PASS " if passed else "FAIL ","Movement uses elapsed time at render/physics rates ",rates," speed=",speed)
		failed=failed or not passed;world.free()
	Engine.physics_ticks_per_second=60
	print("MOVEMENT_TIMING_RESULT ",not failed);quit(1 if failed else 0)
