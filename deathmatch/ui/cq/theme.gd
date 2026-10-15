extends RefCounted
## Wenrexa CC0 Nesia artwork, with Unitblock CC0 typography.
const FONT=preload("res://deathmatch/ui/cq/assets/Unitblock.ttf")
const INK=Color("dceff0")
const ACCENT=Color("65e0d5")
static func texture_box(asset:String,edge:float,margin:float)->StyleBoxTexture:
	var box:=StyleBoxTexture.new();box.texture=load("res://deathmatch/ui/cq/assets/"+asset+".png")
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
		box.set_texture_margin(side,edge);box.set_content_margin(side,margin)
	return box
static func panel(margin:float=18.)->StyleBoxTexture:return texture_box("MainPanel03",8.,margin)
static func theme()->Theme:
	var t:=Theme.new();t.default_font=FONT;t.default_font_size=18;t.set_meta("cq",true)
	for type in ["Label","Button","OptionButton","CheckButton","CheckBox","LineEdit","SpinBox","PopupMenu","TabBar","RichTextLabel"]:
		t.set_color("font_color",type,INK);t.set_color("font_hover_color",type,Color.WHITE);t.set_color("font_pressed_color",type,Color.WHITE);t.set_color("font_focus_color",type,Color.WHITE);t.set_color("font_disabled_color",type,Color("6b858c"))
		t.set_color("font_outline_color",type,Color("081218"));t.set_constant("outline_size",type,1)
	for type in ["Button","OptionButton","LineEdit"]:
		for state in ["normal","hover","pressed","focus","disabled"]:
			var box:=texture_box("Button16" if state=="pressed" else "Button15" if state=="hover" else "Button11",5.,12.)
			if state=="disabled":box.modulate_color=Color(.6,.7,.7,.65)
			if state=="focus":
				var focus:=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_color=ACCENT;focus.set_border_width_all(2);t.set_stylebox(state,type,focus)
			else:t.set_stylebox(state,type,box)
	t.set_stylebox("panel","PanelContainer",panel());t.set_stylebox("panel","PopupMenu",panel(10.))
	var line:=StyleBoxLine.new();line.color=ACCENT;line.thickness=1;t.set_stylebox("separator","HSeparator",line)
	for state in ["scroll","scroll_focus","grabber","grabber_highlight","grabber_pressed"]:
		var bar:=StyleBoxFlat.new();bar.bg_color=ACCENT if state.begins_with("grabber") else Color("102630");bar.content_margin_left=5.;bar.content_margin_top=5.;t.set_stylebox(state,"VScrollBar",bar)
	return t
