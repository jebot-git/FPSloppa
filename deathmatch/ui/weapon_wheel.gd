extends Control
const Icons=preload("res://deathmatch/ui/weapon_icons.gd")
const SIZE:=Vector2(900,900)
const CENTER:=Vector2(450,436)
const OUTER:=380.0
const INNER:=192.0
const INK=Color("e9ddbf")
const GOLD=Color("f4c56b")
const MUTED=Color("929b9e")
var rows: Array=[]
var hover:=-1
var equipped:=-1
var waiting:=false
var font: Font=preload("res://deathmatch/ui/BebasNeue-Regular.ttf")
func _init() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func set_content(items: Array,selected: int,current: int,needs_center: bool) -> bool:
	if rows==items and hover==selected and equipped==current and waiting==needs_center:return false
	rows=items.duplicate(true);hover=selected;equipped=current;waiting=needs_center
	queue_redraw();return true

func ring_point(angle: float,radius: float) -> Vector2:
	return CENTER+Vector2(sin(angle),-cos(angle))*radius

func caption(value: String,center: Vector2,font_size: int,color: Color=INK) -> void:
	var width:=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(font,center-Vector2(width*.5,0),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw() -> void:
	draw_circle(CENTER,OUTER+8,Color("13191ceb"))
	draw_arc(CENTER,OUTER+7,0,TAU,128,Color("777565"),2,true)
	if rows.is_empty():return
	var buying: bool=rows[0].get("buy",false)
	var energy_shop: bool=rows[0].get("currency","")=="ENERGY"
	var desktop: bool=rows[0].get("desktop",false)
	var step:=TAU/rows.size()
	for i in rows.size():
		var row: Dictionary=rows[i]
		var a:=step*i-step*.5+.022;var b:=step*i+step*.5-.022
		var polygon:=PackedVector2Array()
		for j in 33:polygon.append(ring_point(lerpf(a,b,j/32.0),OUTER))
		for j in 33:polygon.append(ring_point(lerpf(b,a,j/32.0),INNER))
		var selected:=hover==i
		draw_colored_polygon(polygon,Color("665131f5") if selected else Color("242b30f2"))
		if int(row.id)==equipped or selected:
			draw_arc(CENTER,OUTER-5,a-PI*.5,b-PI*.5,48,GOLD if selected else Color("a29b72"),5 if selected else 3,true)
		var point:=ring_point(step*i,286)
		var color: Color=GOLD if selected else INK if row.usable else MUTED
		draw_texture_rect(Icons.texture(row.get("icon",row.name)),Rect2(point-Vector2(53,48),Vector2(106,80)),false,color)
		caption(row.get("caption",("" if energy_shop else "$" if buying else "")+str(row.ammo) if row.ammo>=0 else row.name if buying else "—"),point+Vector2(0,58),22 if buying else 26,Color("ed8f78") if not row.usable else color)
	draw_circle(CENTER,INNER-6,Color("141a1ff5"))
	caption("TEAM ENERGY · UNLIMITED" if energy_shop and rows[0].get("infinite_energy",false) else "TEAM ENERGY · %d"%rows[0].cash if energy_shop else "BUY · $%d"%rows[0].cash if buying else "ARSENAL",CENTER+Vector2(0,-128),25,MUTED)
	var index:=hover
	if index<0:
		for i in rows.size():
			if int(rows[i].id)==equipped:index=i;break
	if index>=0:
		var row: Dictionary=rows[index]
		draw_texture_rect(Icons.texture(row.get("icon",row.name)),Rect2(CENTER+Vector2(-72,-114),Vector2(144,108)),false,GOLD)
		var words: PackedStringArray=str(row.name).split(" ")
		if words.size()>1:
			caption(" ".join(words.slice(0,words.size()-1)),CENTER+Vector2(0,30),32)
			caption(words[-1],CENTER+Vector2(0,65),32)
		else:caption(row.name,CENTER+Vector2(0,45),34)
		caption(("UNAVAILABLE" if not row.usable else row.detail if row.has("detail") else ("%d ENERGY" if energy_shop else "$%d")%row.ammo if row.ammo>=0 else "OPEN") if buying else "NO AMMO" if not row.usable else "%d AMMO"%row.ammo if row.ammo>=0 else "UNLIMITED",CENTER+Vector2(0,104),23,Color("ed8f78") if not row.usable else MUTED)
	caption("CLICK TO BUY" if desktop else "CENTER STICK FIRST" if waiting else "RELEASE STICK TO BUY" if buying and hover>=0 else "RELEASE STICK TO EQUIP" if hover>=0 else "TILT RIGHT STICK",CENTER+Vector2(0,148),22,GOLD)
	caption("B / ESC TO CLOSE" if desktop else "PRESS AGAIN TO CANCEL",Vector2(450,870),25,INK)
