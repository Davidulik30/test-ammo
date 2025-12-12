extends Node3D

# Spawns player tanks based on MatchState.players or root meta "lobby_players".
# Expects team spawn nodes `Team1` and `Team2` each containing Marker3D children.

const TANK_PATHS := {
	"Tank": "res://game/tanks/tank.tscn",
	"Predator": "res://game/tanks/predator/predator.tscn",
	"LemanRuss": "res://game/tanks/lemanruss/lemanruss.tscn",
	"Scouter": "res://game/tanks/scouter/scouter.tscn",
	"default": "res://game/tanks/tank.tscn"
}

func _ready() -> void:
	var players: Dictionary = {}
	var local_id = get_tree().get_multiplayer().get_unique_id()
	# read MatchState from Autoload if present
	if get_tree().get_root().has_node("MatchState"):
		var ms = get_tree().get_root().get_node("MatchState")
		players = ms.players.duplicate(true)
		local_id = ms.local_peer_id
	else:
		if get_tree().get_root().has_meta("lobby_players"):
			players = get_tree().get_root().get_meta("lobby_players")
		else:
			players = {}

	if players.size() == 0:
		print("[GameMap] No players data found; skipping spawn.")
		return

	# collect spawn markers for each team
	var team1_markers := []
	var team2_markers := []
	if has_node("Team1"):
		for c in $Team1.get_children():
			if c is Marker3D:
				team1_markers.append(c)
	if has_node("Team2"):
		for c in $Team2.get_children():
			if c is Marker3D:
				team2_markers.append(c)

	if team1_markers.size() == 0 or team2_markers.size() == 0:
		push_warning("No spawn markers found for one or both teams (Team1/Team2).")

	# deterministic order
	var ids = players.keys()
	ids.sort_custom(Callable(self, "_compare_ids"))

	var spawner: Node = null
	if has_node("MultiplayerSpawner"):
		spawner = $MultiplayerSpawner
		# set spawn function so the engine will call _spawner_spawn_function on all peers
		spawner.spawn_function = Callable(self, "_spawner_spawn_function")

	var i := 0
	var team1_idx := 0
	var team2_idx := 0
	for id in ids:
		var info = players[id]
		var tank_name = info.get("tank", null)
		var scene_path: String = TANK_PATHS.get(tank_name, TANK_PATHS["default"])

		# Используем команду из данных игрока
		var team: int = info.get("team", 1)
		if team == 0:
			team = 1  # По умолчанию команда 1
		
		var marker_list = team1_markers if team == 1 else team2_markers
		var spawn_xform = Transform3D()
		if marker_list.size() > 0:
			var spawn_idx: int = 0
			if team == 1:
				spawn_idx = team1_idx % marker_list.size()
				team1_idx += 1
			else:
				spawn_idx = team2_idx % marker_list.size()
				team2_idx += 1
			spawn_xform = marker_list[spawn_idx].global_transform

		if spawner != null:
			# server calls spawn() (authority). the engine will replicate spawned nodes to clients
			if _is_server():
				spawner.spawn({"scene": scene_path, "transform": spawn_xform, "owner": int(id)})
			else:
				# clients: do nothing here — server spawns and MultiplayerSpawner replicates the instances
				pass
		else:
			# fallback: local instantiate
			var res = ResourceLoader.load(scene_path)
			if res and res is PackedScene:
				var n = res.instantiate()
				if n is Node3D:
					n.global_transform = spawn_xform
				add_child(n)
				var inst = n
				inst.name = "Player_%s" % str(id)
				if str(id) == str(local_id) or int(id) == int(local_id):
					var cam = inst.find_node("RegularCamera", true, false)
					if cam and cam is Camera3D:
						cam.current = true
			else:
				push_error("Failed to load tank scene: %s" % scene_path)

		i += 1

func _compare_ids(a, b):
	# ensure numeric comparison where possible
	var ai = int(a)
	var bi = int(b)
	return ai - bi


func _is_server() -> bool:
	# prefer MultiplayerAPI.is_server when available, fallback to id==1
	if Engine.has_singleton("Engine"):
		# try to use SceneTree.multiplayer API if present
		if get_tree().has_method("get_multiplayer"):
			var mp = get_tree().get_multiplayer()
			if mp and mp.has_method("is_server"):
				return mp.is_server()
	# fallback: common ENet server peer id is 1
	return int(get_tree().get_multiplayer().get_unique_id()) == 1


func _spawner_spawn_function(data: Dictionary) -> Node:
	# Called on all peers by MultiplayerSpawner when authority requests a custom spawn.
	# Should return a node instance (not added to the tree) that the engine will add under spawn_path.
	var scene_path = data.get("scene", "")
	var owner_id = int(data.get("owner", 0))
	var xform: Transform3D = data.get("transform", Transform3D())

	var res = ResourceLoader.load(scene_path)
	if res == null or not (res is PackedScene):
		push_error("_spawner_spawn_function: failed to load scene: %s" % scene_path)
		return null

	var inst = (res as PackedScene).instantiate()
	if inst is Node3D:
		inst.global_transform = xform
		# set a deterministic name and metadata for owner lookup
		inst.name = "Player_%s" % str(owner_id)
		if inst.has_method("set_meta"):
			inst.set_meta("owner_id", owner_id)

	# set network authority on the instance (server only)
	# Prefer modern API `set_multiplayer_authority`; fall back to older `set_network_master`.
	# Only attempt to set authority on the server (the spawn_function is executed where the spawn is requested).
	if Engine.has_singleton("Engine"):
		# If the instance supports the modern API, use it.
		if inst.has_method("set_multiplayer_authority"):
			inst.call("set_multiplayer_authority", owner_id)
		elif inst.has_method("set_network_master"):
			inst.call("set_network_master", owner_id)
		# else: no authority API available on this node type; ignore.

	return inst
