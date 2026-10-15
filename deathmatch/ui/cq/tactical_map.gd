extends PanelContainer
## Read-only combat overview. It never issues a deployment request.
var game
var overview
var selected:=""
var service
var elapsed:=0.
func setup(arena)->void:
 game=arena;service=game.squads
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 offset_left=-400;offset_right=400;offset_top=-255;offset_bottom=255
 add_theme_stylebox_override("panel",preload("res://deathmatch/ui/cq/theme.gd").panel(12))
 overview=preload("res://deathmatch/ui/cq/deployment.gd").Overview.new();overview.view=self;overview.read_only=true;overview.custom_minimum_size=Vector2(680,460);add_child(overview);hide()
func zones()->Array:return service.screen.zones() if service.screen else []
func members()->Array:return service.screen.members() if service.screen else []
func _process(delta:float)->void:
 if not visible:return
 elapsed+=delta
 if elapsed>=.1:elapsed=0;overview.queue_redraw()
