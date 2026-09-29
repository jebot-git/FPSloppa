extends "res://deathmatch/arena.gd"
## The benchmark owns startup and binds an ephemeral loopback port. Production
## dedicated _ready otherwise also starts server.cfg before the fixture is set up.
func _start_dedicated(_args: PackedStringArray) -> void:
	pass
