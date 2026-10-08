extends RefCounted
## The only non-input operations a worker may request. No arbitrary method dispatch.
const SIGNATURES={"st_vehicle_buy":[TYPE_INT,TYPE_STRING],"st_vehicle_board":[TYPE_INT,TYPE_INT],"st_vehicle_leave":[TYPE_INT],"team_chat":[TYPE_INT,TYPE_STRING],"st_order_complete":[TYPE_INT],"tf_action":[TYPE_INT,TYPE_STRING],"st_kit":[TYPE_INT],"st_refit":[TYPE_INT,TYPE_STRING,TYPE_ARRAY,TYPE_STRING,TYPE_BOOL],"st_beacon_buy":[TYPE_INT],"st_deploy":[TYPE_INT,TYPE_VECTOR3,TYPE_VECTOR3],"st_beacon":[TYPE_INT,TYPE_VECTOR3,TYPE_VECTOR3],"st_drop":[TYPE_INT,TYPE_VECTOR3,TYPE_VECTOR3],"de_buy":[TYPE_INT,TYPE_INT],"de_use":[TYPE_INT],"de_plant":[TYPE_INT,TYPE_INT],"de_digit":[TYPE_INT,TYPE_INT],"de_lock_defuse":[TYPE_INT],"de_cut":[TYPE_INT,TYPE_INT],"de_bot_stow_objective":[TYPE_INT],"de_hold":[TYPE_INT],"de_tool":[TYPE_INT],"de_equip":[TYPE_INT,TYPE_INT],"de_throw":[TYPE_INT,TYPE_VECTOR3],"de_cancel":[TYPE_INT]}
static func valid(kind: String,args: Array) -> bool:
	if not SIGNATURES.has(kind) or args.size()!=SIGNATURES[kind].size():return false
	for i in args.size():
		if typeof(args[i])!=SIGNATURES[kind][i]:return false
		if args[i] is Vector3 and not args[i].is_finite():return false
		if args[i] is String and args[i].length()>(140 if kind=="team_chat" else 32):return false
	if args[0]>=0:return false
	if kind=="st_refit":
		if args[2].size()>8:return false
		for value in args[2]:
			if not value is int or value<0 or value>11:return false
	return true
static func execute(game,kind: String,args: Array):
	if not valid(kind,args) or not game.active or game.map_loading or game.intermission>0 or game.lobby.active():return false
	var id: int=args[0]
	if not game.players.has(id) or not game.fighters.has(id) or game.players[id].dead or game.players[id].spectator:return false
	var st=game.match_mode.tribes;var de=game.match_mode.defusal
	if kind.begins_with("st_") and not st.enabled():return false
	if kind.begins_with("de_") and not de.enabled():return false
	if kind in ["st_deploy","st_beacon","st_drop"]:
		if args[1].distance_to(game.fighters[id].position)>3 or args[2].length()>(35 if kind=="st_drop" else 1.01):return false
	match kind:
		"team_chat":game._chat_for(id,args[1],true);return true
		"st_order_complete":
			var order: Dictionary=st.commander.orders.get(id,{})
			if order.is_empty() or order.status!="accepted" or order.life!=game.players[id].serial or order.verb=="defend" or game.fighters[id].position.distance_to(order.point)>=6:return false
			order.status="complete";return true
		"tf_action":
			if args[1] not in ["sentry","dispenser"]:return false
			game.players[id].tf_tool=args[1];game.match_mode.fortress.action(id);return true
		"st_vehicle_buy":return st.vehicles.purchase(id,game.map_epoch,game.players[id].serial,args[1])
		"st_vehicle_board":return st.vehicles.board(id,args[1],0)
		"st_vehicle_leave":return st.vehicles.leave(id)
		"st_kit":return st.kit(id)
		"st_refit":return st.select_equipment(id,args[1],args[2],args[3],args[4])
		"st_beacon_buy":return st.targeting.buy(id)
		"st_deploy":return st.deployables.deploy(id,args[1],args[2])
		"st_beacon":return st.targeting.place(id,args[1],args[2])
		"st_drop":return game.match_mode.st.drop(id,args[1],args[2])
		"de_buy":return de.buy(id,args[1])
		"de_use":return de.use(id)
		"de_plant":return de.plant(id,args[1])
		"de_digit":return de.digit(id,args[1])
		"de_lock_defuse":
			if de.phase!="live" or not de.planted or de.role(id)!=1 or not de.reachable(id,de.bomb_position,1.5):return false
			return de.lock_defuse(id)
		"de_cut":return de.cut(id,args[1])
		"de_bot_stow_objective":de.bot_stow_objective(id)
		"de_hold":
			if de.phase!="live" or de.carrier!=id:return false
			de.held=true
		"de_tool":
			if de.phase!="live" or not de.account(id).kit:return false
			de.account(id).tool=true
		"de_equip":return de.utility.equip(id,args[1])
		"de_throw":
			if args[1].length()>50:return false
			return de.utility.throw_grenade(id,args[1])
		"de_cancel":de.utility.cancel(id)
	return true
