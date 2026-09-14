extends "res://deathmatch/vehicles/ba2/controller.gd"
## Historical baseline only; never loaded by the game or dedicated server.
func pilot_max_health(id: int) -> int:return tf.definition(id).hp
func restore_pilot_health(_id: int) -> void:pass
