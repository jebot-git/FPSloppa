extends "res://deathmatch/server/log.gd"
## Test-only, passive combat evidence. Uses the normal damage log hook; never
## changes perception, health, equipment or commands sent to the bots.
var evidence: FileAccess
func record(event: String,data: Dictionary={},_detail: int=1) -> void:
	if not evidence or not game or event!="damage":return
	var row: Dictionary={"seconds":game.clock,"event":event,"data":data.duplicate(true)}
	for key in ["victim","attacker"]:
		var id: int=int(data.get(key,0))
		if not game.fighters.has(id):continue
		var brain: Dictionary=game.bots.brains.get(id,{})
		row[key]={"position":game.fighters[id].position,"velocity":game.fighters[id].velocity,"carrier":game.match_mode.st.carried(id)>=0,"role":brain.get("role",""),"enemy":brain.get("enemy",0),"visible":brain.get("visible",[]).duplicate(),"weapon":game.players[id].weapon}
	evidence.store_line(JSON.stringify(row))
	if data.get("fatal",false):evidence.flush()
