extends RefCounted
## Original code-drawn iron / brass theme; no proprietary game UI artwork.
const INK=Color("e5d5ad")
const GOLD=Color("c59a56")
static func panel(margin: float=18.0) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=Color("211e1a");s.border_color=Color("766044");s.set_border_width_all(2)
	s.border_width_top=4;s.border_blend=true;s.shadow_color=Color(0,0,0,.65);s.shadow_size=8
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:s.set_content_margin(side,margin)
	return s
static func theme() -> Theme:
	var t:=Theme.new();t.default_font_size=16
	for type in ["Label","Button","OptionButton","CheckButton","CheckBox","LineEdit","SpinBox","PopupMenu","TabBar"]:
		t.set_color("font_color",type,INK);t.set_color("font_hover_color",type,Color("fff0ca"));t.set_color("font_pressed_color",type,Color("fff0ca"));t.set_color("font_focus_color",type,Color("fff0ca"));t.set_color("font_disabled_color",type,Color("928777"))
		t.set_color("font_outline_color",type,Color("100d0b"));t.set_constant("outline_size",type,2)
	for type in ["Button","OptionButton","LineEdit"]:
		for state in ["normal","hover","pressed","focus","disabled"]:
			var s:=panel(7);s.shadow_size=0;s.border_width_top=2
			s.bg_color=Color("332c23") if state=="normal" else Color("53412c") if state=="hover" else Color("632a23") if state=="pressed" else Color("201c18")
			if state=="focus":s.bg_color=Color.TRANSPARENT;s.border_color=GOLD
			if state=="disabled":s.border_color=Color("40392f")
			t.set_stylebox(state,type,s)
	t.set_stylebox("panel","PanelContainer",panel());t.set_stylebox("panel","PopupMenu",panel(8))
	var separator:=StyleBoxLine.new();separator.color=GOLD;separator.thickness=2;t.set_stylebox("separator","HSeparator",separator)
	var trough:=panel(0);trough.bg_color=Color("100e0c");trough.content_margin_top=4;trough.content_margin_bottom=4;t.set_stylebox("slider","HSlider",trough)
	var fill:=trough.duplicate();fill.bg_color=GOLD;t.set_stylebox("grabber_area","HSlider",fill);t.set_stylebox("grabber_area_highlight","HSlider",fill)
	return t
