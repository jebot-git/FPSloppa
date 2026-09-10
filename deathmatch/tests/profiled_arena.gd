extends "res://deathmatch/arena.gd"
var audit_projectile_us:=0
var audit_history_us:=0
var audit_collect_us:=0
var audit_melee_us:=0
var audit_ticks:=0
func _update_projectiles(delta: float,movement_start: Dictionary={}) -> void:
	var before:=Time.get_ticks_usec();super._update_projectiles(delta,movement_start);audit_projectile_us+=Time.get_ticks_usec()-before;audit_ticks+=1
func _record_history() -> void:
	var before:=Time.get_ticks_usec();super._record_history();audit_history_us+=Time.get_ticks_usec()-before
func _collect(id: int) -> void:
	var before:=Time.get_ticks_usec();super._collect(id);audit_collect_us+=Time.get_ticks_usec()-before
func _update_melee(id: int) -> void:
	var before:=Time.get_ticks_usec();super._update_melee(id);audit_melee_us+=Time.get_ticks_usec()-before
# Test-only A/B control: avoid constructing history when no rewind is requested.
func _rewound_positions(rewind: float) -> Dictionary:
	if OS.get_cmdline_user_args().has("--skip-zero-rewind") and rewind<=0:return {}
	return super._rewound_positions(rewind)
