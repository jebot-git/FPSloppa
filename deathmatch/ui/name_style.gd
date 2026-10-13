extends RefCounted
## Q3-style ^0–^7 colour runs. User text is always literal, never BBCode.
const COLORS=[Color.BLACK,Color.RED,Color.GREEN,Color.YELLOW,Color.BLUE,Color.CYAN,Color.MAGENTA,Color.WHITE]
const TITLES=["Black","Red","Green","Yellow","Blue","Cyan","Magenta","White"]
const NAME_LIMIT=18
const CLAN_LIMIT=8
const DISPLAY_LIMIT=NAME_LIMIT+CLAN_LIMIT+3
const INPUT_LIMIT=128
static func runs(value: String) -> Array:
	var result: Array=[];var text:="";var colour:=-1;var i:=0
	while i<value.length():
		if value[i]=="^" and i+1<value.length():
			if value[i+1]=="^":text+="^";i+=2;continue
			if value[i+1] in "01234567":
				if not text.is_empty():result.append({"text":text,"colour":colour});text=""
				colour=int(value[i+1]);i+=2;continue
		text+=value[i];i+=1
	if not text.is_empty():result.append({"text":text,"colour":colour})
	return result
static func plain(value: String) -> String:
	var text:=""
	for run in runs(value):text+=run.text
	return text
static func clean(value: String,limit: int=NAME_LIMIT,fallback: String="Marine",brackets: bool=false) -> String:
	var output:="";var visible:=0;var previous:=-1
	for run in runs(value.left(INPUT_LIMIT).strip_edges()):
		var text:=""
		for ch in str(run.text):
			var code:=ch.unicode_at(0)
			if code<32 or code==127 or code in [0x200b,0x200c,0x200d,0x200e,0x200f,0xfeff] or (code>=0x202a and code<=0x202e) or (code>=0x2066 and code<=0x2069):continue
			if not brackets and ch in ["[","]"]:continue
			if visible>=limit:break
			text+="^^" if ch=="^" else ch;visible+=1
		if not text.is_empty():
			if run.colour!=previous and run.colour>=0:output+="^"+str(run.colour)
			output+=text;previous=run.colour
		if visible>=limit:break
	if plain(output).strip_edges().is_empty():return fallback
	output=output.strip_edges()
	return output+("^7" if previous>=0 and previous!=7 else "")
static func display(name: String,clan: String="") -> String:
	var tag:=clean(clan,CLAN_LIMIT,"");var callsign:=clean(name)
	var result:=("["+tag+"^7] " if not tag.is_empty() else "")+callsign
	return result+("^7" if runs(result).any(func(run):return run.colour>=0) else "")
static func rich_label(width: float=0,height: float=26,size: int=18) -> RichTextLabel:
	var label:=RichTextLabel.new();label.custom_minimum_size=Vector2(width,height)
	label.bbcode_enabled=false;label.scroll_active=false;label.autowrap_mode=TextServer.AUTOWRAP_OFF
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.add_theme_font_size_override("normal_font_size",size)
	return label
static func paint(label: RichTextLabel,value: String,base: Color=Color.WHITE) -> void:
	if label.has_meta("name_source") and label.get_meta("name_source")==value and label.get_meta("name_base")==base:return
	label.set_meta("name_source",value);label.set_meta("name_base",base);label.clear()
	for run in runs(value):
		label.push_color(COLORS[run.colour] if run.colour>=0 else base)
		label.add_text(run.text);label.pop()
