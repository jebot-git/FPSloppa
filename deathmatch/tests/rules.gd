extends SceneTree
const W = preload("res://deathmatch/weapons.gd")
var failures: Array = []

func check(value: bool,label: String) -> void:
	if not value: failures.append(label)
	print("PASS " if value else "FAIL ",label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var config=preload("res://deathmatch/server/config.gd")
	check(config.parse('set sv_maxclients 16').values.sv_maxclients==16,"Dedicated config accepts sixteen players")
	check(config.parse('set sv_maxclients 17').has("error"),"Dedicated config rejects more than sixteen players")
	check(config.parse('').values.sv_maxclients==8,"Dedicated default remains eight players")
	check(W.DATA[3].pellets==7 and W.DATA[4].pellets==20,"Shotgun pellet counts")
	check(W.can_fire(0,[0,0,0,0]) and W.can_fire(1,[0,0,0,0]),"Melee needs no ammunition")
	check(not W.can_fire(4,[50,1,0,0]),"Super shotgun requires two shells")
	check(not W.can_fire(8,[0,0,0,39]) and W.can_fire(8,[0,0,0,40]),"BFG requires forty cells")
	check(W.armor_damage(60,100,1)==Vector2i(40,80),"Green armor absorbs one third")
	check(W.armor_damage(60,200,2)==Vector2i(30,170),"Blue armor absorbs one half")
	check(W.armor_damage(60,5,2)==Vector2i(55,0),"Depleted armor does not absorb excess")
	check(W.next_owned(2,1,[0,2,6])==6,"Weapon cycling skips unowned weapons")
	var scene = load("res://deathmatch/arena.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.active = true
	scene.players[1] = scene._new_state("Test",1)
	scene._create_fighter(1)
	var s: Dictionary = scene.players[1]
	scene._accept_input(1,{"seq":1,"move":Vector2(500,500),"yaw":0.0,"pitch":99.0,"fire":true,"weapon":8,"slow":false,"respawn":false,"hp":9999})
	check(s.move.length()<=1.001 and s.pitch<=1.45,"Server clamps movement and pitch")
	check(s.weapon==2 and s.hp==100,"Unowned weapons and client health are rejected")
	scene._accept_input(1,{"seq":2,"move":Vector2(NAN,0),"yaw":0.0,"pitch":0.0,"fire":true,"weapon":2,"slow":false,"respawn":false})
	check(s.last_seq==1,"Non-finite input rejected")
	scene._accept_input(1,{"seq":0,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":false,"weapon":2,"slow":false,"respawn":false})
	check(s.last_seq==1,"Stale input rejected")
	scene._accept_input(44,{"seq":5})
	check(scene.players.size()==1,"Unknown peer cannot create a player with input")
	scene.active = false
	scene.queue_free()
	await process_frame
	print("RULES_RESULT ",JSON.stringify({"passed":16-failures.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
