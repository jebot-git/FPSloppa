extends RefCounted
## Unified-map CQ. Capture speed is independent of the number of occupants.
const CAPTURE_SECONDS:=10.0
const INCOME_SECONDS:=10.0
const LIMIT:=200
var owners:Array=[]
var progress:Array=[]
var contested:Array=[]
var credit:Array=[]
var scores:Array=[0,0]
var winner:=-2 # -2 active, -1 simultaneous draw, 0/1 winning team.
func reset(count:int) -> void:
	owners.clear();progress.clear();contested.clear();credit.clear();scores=[0,0];winner=-2
	for zone in count:owners.append(-1);progress.append([0.0,0.0]);contested.append(false);credit.append(0.0)
func held(team:int) -> int:return owners.count(team)
func decide() -> void:
	if winner!=-2:return
	if scores[0]>=LIMIT and scores[1]>=LIMIT:winner=-1
	elif scores[0]>=LIMIT:winner=0
	elif scores[1]>=LIMIT:winner=1
func kill(team:int) -> int:
	if winner!=-2 or team not in [0,1]:return 0
	var points:=held(team);scores[team]=mini(LIMIT,scores[team]+points);decide();return points
func advance(delta:float,presence:Array) -> Array:
	var changed:Array=[]
	if winner!=-2 or presence.size()!=owners.size():return changed
	for zone in owners.size():
		contested[zone]=bool(presence[zone][0]) and bool(presence[zone][1])
		for team in 2:
			if not presence[zone][team] or owners[zone]==team:progress[zone][team]=0.0
	# Split at capture/income boundaries: no retroactive scoring after a capture,
	# and a long step cannot let a later scoring event steal an earlier win.
	var remaining:=maxf(0,delta)
	while remaining>.000001 and winner==-2:
		var step:=remaining
		for zone in owners.size():
			if owners[zone]>=0:step=minf(step,maxf(.000001,INCOME_SECONDS-credit[zone]))
			if contested[zone]:continue
			var team:=0 if presence[zone][0] else 1 if presence[zone][1] else -1
			if team>=0 and owners[zone]!=team:step=minf(step,maxf(.000001,CAPTURE_SECONDS-progress[zone][team]))
		for zone in owners.size():
			if owners[zone]>=0:
				credit[zone]+=step
				if credit[zone]+.000001>=INCOME_SECONDS:
					scores[owners[zone]]=mini(LIMIT,scores[owners[zone]]+1);credit[zone]=maxf(0,credit[zone]-INCOME_SECONDS)
			if contested[zone]:continue
			var team:=0 if presence[zone][0] else 1 if presence[zone][1] else -1
			if team<0 or owners[zone]==team:continue
			progress[zone][team]+=step
			if progress[zone][team]+.000001>=CAPTURE_SECONDS:
				owners[zone]=team;progress[zone]=[0.0,0.0];credit[zone]=0.0;changed.append(zone)
		remaining-=step;decide()
	return changed
func snapshot() -> Dictionary:return {"owners":owners.duplicate(),"progress":progress.duplicate(true),"contested":contested.duplicate(),"credit":credit.duplicate(),"scores":scores.duplicate(),"winner":winner}
func receive(data:Dictionary) -> void:
	if data.get("owners",[]).size()!=owners.size():return
	owners=data.owners.duplicate();progress=data.progress.duplicate(true);contested=data.contested.duplicate();credit=data.credit.duplicate();scores=data.scores.duplicate();winner=data.winner
