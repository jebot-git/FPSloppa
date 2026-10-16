extends Control
func _draw()->void:
 var ink:=Color("7bffe2")
 draw_line(Vector2(176,120),Vector2(188,120),ink,1.)
 draw_line(Vector2(196,120),Vector2(208,120),ink,1.)
 draw_line(Vector2(192,104),Vector2(192,116),ink,1.)
 draw_line(Vector2(192,124),Vector2(192,136),ink,1.)
 draw_circle(Vector2(192,120),1.5,Color("ff6b52"))
 draw_string(ThemeDB.fallback_font,Vector2(12,226),"ENERGY OPTIC · 3×",HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
