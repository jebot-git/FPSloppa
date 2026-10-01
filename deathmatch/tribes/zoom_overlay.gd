extends Control
## Full-view green cross from the retail T1 image enhancer (not a tube optic).
const GREEN=Color(.20,.95,.24,.78)
var aim:=Vector2(.5,.5)
var aim_visible:=true
var amount:=2.0
var label_anchor:=Vector2(0,1)
var label_offset:=Vector2(24,-110)
var label_size:=20
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
func display(value: float,point:=Vector2(.5,.5),valid:=true) -> void:
	if amount==value and aim==point and aim_visible==valid:return
	amount=value;aim=point;aim_visible=valid;queue_redraw()
func _draw() -> void:
	if aim_visible:
		var p: Vector2=(size*aim).floor()+Vector2(.5,.5)
		# A dark one-pixel backing keeps the thin green lines legible on snow.
		for row in [[Vector2(0,p.y),Vector2(size.x,p.y)],[Vector2(p.x,0),Vector2(p.x,size.y)]]:
			draw_line(row[0],row[1],Color(0,.08,0,.45),3)
			draw_line(row[0],row[1],GREEN,1.5,true)
	draw_string(ThemeDB.fallback_font,size*label_anchor+label_offset,"%d×"%int(amount),HORIZONTAL_ALIGNMENT_LEFT,-1,label_size,GREEN)
