extends Label3D
## All runs share one billboard origin; pixel offsets remain aligned in VR and
## at oblique camera angles. No per-frame viewport or texture rendering needed.
const Names=preload("res://deathmatch/ui/name_style.gd")
var signature:=""
var pieces: Array[Label3D]=[]
func set_player_name(nickname: String,team: int,color: Color) -> void:
	var key:=nickname+str(team)+color.to_html()
	if key==signature:return
	signature=key
	for piece in pieces:remove_child(piece);piece.queue_free()
	pieces.clear()
	var prefix:="◆ " if team==0 else "● " if team==1 else ""
	var base:=color.lightened(.2 if team in [0,1] else .4)
	text=prefix+Names.plain(nickname);modulate=base
	var runs:=Names.runs(nickname)
	if not runs.any(func(run):return run.colour>=0):return
	# Base text stays available to accessibility/tests; only the coloured runs draw.
	modulate.a=0
	if not prefix.is_empty():runs.push_front({"text":prefix,"colour":-1})
	var face: Font=font if font else ThemeDB.fallback_font
	var left:=-face.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x/2.0
	var before:=""
	for run in runs:
		var part:=Label3D.new();part.text=run.text;part.font=face;part.font_size=font_size;part.pixel_size=pixel_size
		part.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;part.vertical_alignment=vertical_alignment
		part.offset=Vector2(left+face.get_string_size(before,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x,0)
		part.billboard=billboard;part.no_depth_test=no_depth_test;part.outline_size=outline_size
		part.outline_modulate=Color(.3,.3,.3,1) if run.colour==0 else outline_modulate
		part.modulate=Names.COLORS[run.colour] if run.colour>=0 else base
		add_child(part);pieces.append(part);before+=str(run.text)
