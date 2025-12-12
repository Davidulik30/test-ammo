extends Node

# Network manager for lobby + tank selection
# Works with ENet (Godot 4.x). Add this node to your lobby scene as a child
# or make it an Autoload for project-wide access.

signal player_list_updated(players)
signal connected()
signal disconnected()
signal connection_failed()

var players := {} # peer_id -> {name: String, tank: String/null}
var is_server := false
var player_name: String = "Player"
const DEFAULT_PORT: int = 8910

func _get_local_name() -> String:
	var uname = "Player"
	if OS.has_environment("USERNAME"):
		uname = OS.get_environment("USERNAME")
	elif OS.has_environment("USER"):
		uname = OS.get_environment("USER")
	return uname

func _ready():
	# connect multiplayer signals (use SceneTree.get_multiplayer() API in Godot 4.5)
	var mp = get_tree().get_multiplayer()
	if not mp.is_connected("peer_connected", Callable(self, "_on_peer_connected")):
		mp.connect("peer_connected", Callable(self, "_on_peer_connected"))
	if not mp.is_connected("peer_disconnected", Callable(self, "_on_peer_disconnected")):
		mp.connect("peer_disconnected", Callable(self, "_on_peer_disconnected"))

	# keep client connection lifecycle signals on the MultiplayerAPI (Godot 4.x)
	# MultiplayerAPI emits connected_to_server/connection_failed/server_disconnected
	if not mp.is_connected("connected_to_server", Callable(self, "_on_connected_to_server")):
		mp.connect("connected_to_server", Callable(self, "_on_connected_to_server"))
	if not mp.is_connected("connection_failed", Callable(self, "_on_connection_failed")):
		mp.connect("connection_failed", Callable(self, "_on_connection_failed"))
	if not mp.is_connected("server_disconnected", Callable(self, "_on_server_disconnected")):
		mp.connect("server_disconnected", Callable(self, "_on_server_disconnected"))

### Hosting / Joining
func host(port: int = 7777, max_clients: int = 8) -> void:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, max_clients)
	if err != OK:
		push_error("Failed to create server: %s" % err)
		emit_signal("connection_failed")
		return
	# set multiplayer peer via SceneTree.get_multiplayer() for Godot 4.x
	# use the MultiplayerAPI property 'multiplayer_peer'
	get_tree().get_multiplayer().multiplayer_peer = peer
	is_server = true
	var my_id = get_tree().get_multiplayer().get_unique_id()
	players.clear()
	players[my_id] = {"name": _get_local_name(), "tank": null, "team": 0, "ready": false}
	# broadcast current player list to connected peers
	rpc("client_update_player_list", players)
	emit_signal("connected")
	# If UI expects the older host_game flow, ensure player_name mirrors
	player_name = _get_local_name()

func join(ip: String, port: int) -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	get_tree().get_multiplayer().multiplayer_peer = peer
	# keep player_name consistent for compatibility
	player_name = _get_local_name()

func quit_network() -> void:
	get_tree().get_multiplayer().multiplayer_peer = null
	players.clear()
	is_server = false
	emit_signal("disconnected")

func _exit_tree() -> void:
	# clean up connections to avoid duplicates if node is freed/reloaded
	var mp = get_tree().get_multiplayer()
	if mp.is_connected("peer_connected", Callable(self, "_on_peer_connected")):
		mp.disconnect("peer_connected", Callable(self, "_on_peer_connected"))
	if mp.is_connected("peer_disconnected", Callable(self, "_on_peer_disconnected")):
		mp.disconnect("peer_disconnected", Callable(self, "_on_peer_disconnected"))

	if mp.is_connected("connected_to_server", Callable(self, "_on_connected_to_server")):
		mp.disconnect("connected_to_server", Callable(self, "_on_connected_to_server"))
	if mp.is_connected("connection_failed", Callable(self, "_on_connection_failed")):
		mp.disconnect("connection_failed", Callable(self, "_on_connection_failed"))
	if mp.is_connected("server_disconnected", Callable(self, "_on_server_disconnected")):
		mp.disconnect("server_disconnected", Callable(self, "_on_server_disconnected"))

### SceneTree signals handlers
func _on_peer_connected(id: int) -> void:
	if is_server:
		# add placeholder for new peer with team and ready status
		players[id] = {"name": "Player_%d" % id, "tank": null, "team": 0, "ready": false}
		rpc("client_update_player_list", players)

func _on_peer_disconnected(id: int) -> void:
	if is_server:
		players.erase(id)
		rpc("client_update_player_list", players)
	else:
		# client noticed someone left
		# server will broadcast updated list
		pass

func _on_connected_to_server() -> void:
	# register ourselves with the server: send name
	var my_name = _get_local_name()
	# call server method using compatibility shim name if server expects it
	# prefer calling server_register_player if present
	if has_method("server_register_player"):
		rpc_id(get_server_id(), "server_register_player", my_name)
	else:
		rpc_id(get_server_id(), "server_register_player", my_name)
	emit_signal("connected")

func _on_connection_failed() -> void:
	emit_signal("connection_failed")

func _on_server_disconnected() -> void:
	emit_signal("disconnected")


func get_server_id() -> int:
	var mp = get_tree().get_multiplayer()
	# If we're the server, return our id
	if is_server:
		return mp.get_unique_id()
	# Common ENet server id is 1 — use as a sensible default
	return 1

### RPCs -- server authoritative handlers
@rpc("any_peer")
func server_register_player(player_name: String) -> void:
	# Only server should process
	if not is_server:
		return
	var id = get_tree().get_multiplayer().get_remote_sender_id()
	# If this was called locally on the server (no RPC context), remote_sender_id() is 0.
	# Fall back to the server's own unique id so local calls work as expected.
	if id == 0:
		id = get_tree().get_multiplayer().get_unique_id()
	print("[NetworkManager] server_register_player: sender_id=%d name=%s" % [id, player_name])
	players[id] = {"name": player_name, "tank": null, "team": 0, "ready": false}
	print("[NetworkManager] players after register: %s" % players)
	rpc("client_update_player_list", players)
	# compatibility: also respond to older send_player_info flow if used
	# (some older UI calls register/update using different rpc names)
	if has_method("update_player_list"):
		# call legacy RPC name on clients
		rpc("update_player_list", players)

@rpc("any_peer")
func server_set_tank(tank_name: String) -> void:
	if not is_server:
		return
	var id = get_tree().get_multiplayer().get_remote_sender_id()
	if id == 0:
		id = get_tree().get_multiplayer().get_unique_id()
	print("[NetworkManager] server_set_tank: sender_id=%d tank=%s" % [id, tank_name])
	if players.has(id):
		players[id]["tank"] = tank_name
	else:
		players[id] = {"name": "Player_%d" % id, "tank": tank_name, "team": 0, "ready": false}
	print("[NetworkManager] players after set_tank: %s" % players)
	rpc("client_update_player_list", players)

@rpc("any_peer")
func server_set_team(team: int) -> void:
	if not is_server:
		return
	var id = get_tree().get_multiplayer().get_remote_sender_id()
	if id == 0:
		id = get_tree().get_multiplayer().get_unique_id()
	print("[NetworkManager] server_set_team: sender_id=%d team=%d" % [id, team])
	if players.has(id):
		players[id]["team"] = team
		players[id]["ready"] = false  # сбрасываем готовность при смене команды
	else:
		players[id] = {"name": "Player_%d" % id, "tank": null, "team": team, "ready": false}
	print("[NetworkManager] players after set_team: %s" % players)
	rpc("client_update_player_list", players)

@rpc("any_peer")
func server_set_ready(is_ready: bool) -> void:
	if not is_server:
		return
	var id = get_tree().get_multiplayer().get_remote_sender_id()
	if id == 0:
		id = get_tree().get_multiplayer().get_unique_id()
	print("[NetworkManager] server_set_ready: sender_id=%d ready=%s" % [id, is_ready])
	if players.has(id):
		# Проверяем что игрок выбрал команду и танк
		if is_ready:
			if players[id].get("team", 0) == 0:
				print("[NetworkManager] Cannot ready: no team selected")
				return
			if players[id].get("tank", null) == null:
				print("[NetworkManager] Cannot ready: no tank selected")
				return
		players[id]["ready"] = is_ready
	print("[NetworkManager] players after set_ready: %s" % players)
	rpc("client_update_player_list", players)
	# Проверяем все ли готовы для автостарта
	_check_all_ready()

func _check_all_ready() -> void:
	if not is_server:
		return
	if players.size() == 0:
		return
	for id in players.keys():
		if not players[id].get("ready", false):
			return
	# Все готовы - запускаем игру!
	print("[NetworkManager] All players ready! Starting game...")
	server_request_start()

@rpc("authority")
func server_request_start() -> void:
	if not is_server:
		return
	print("[NetworkManager] server_request_start called; players: %s" % players)
	# verify all players have chosen tanks
	for id in players.keys():
		var p = players[id]
		print("[NetworkManager] checking player %d -> %s" % [id, p])
		if p["tank"] == null:
			push_warning("Player %s hasn't selected a tank yet" % p["name"])
			print("[NetworkManager] aborting start because player %d (%s) has no tank" % [id, p["name"]])
			return
	# broadcast countdown
	var countdown = 1
	rpc("client_start_countdown", countdown)
	# after countdown, load the game scene for all clients
	var t = Timer.new()
	t.one_shot = true
	t.wait_time = countdown
	add_child(t)
	t.start()
	await t.timeout
	print("timer out")
	# pass players data to clients and ask them to load the scene
	# Use per-peer rpc_id to improve delivery reliability, and call locally for the host.
	var mp = get_tree().get_multiplayer()
	var peers = mp.get_peers()
	for peer_id in peers:
		print("[NetworkManager] sending client_load_scene to peer %d" % peer_id)
		rpc_id(peer_id, "client_load_scene", "res://game/maps/game_map.tscn", players)
	# also call locally on the server (host)
	print("[NetworkManager] calling client_load_scene locally for host")
	client_load_scene("res://game/maps/game_map.tscn", players)

### Client RPCs
@rpc("call_local")
func client_update_player_list(new_players: Dictionary) -> void:
	players = new_players.duplicate(true)
	print("[NetworkManager] client_update_player_list received: %s" % players)
	emit_signal("player_list_updated", players)

@rpc("call_local")
func client_start_countdown(seconds: int) -> void:
	# forwarded to UI via signal, clients can show timer
	# we'll reuse player_list_updated signal to carry UI events or rely on direct connection
	# emit a quick signal as well
	print("[NetworkManager] client_start_countdown: %d seconds" % seconds)
	emit_signal("player_list_updated", players)
	# UI nodes can listen to this node and start their own countdown when they receive this rpc
	print("Countdown started: %d" % seconds)

@rpc("call_local")
func client_load_scene(scene_path: String, players_data: Dictionary) -> void:
	# store players into MatchState (recommended autoload) if present
	# In Godot 4.5 Autoloads become children of the root. Avoid Engine.get_singleton usage.
	if get_tree().get_root().has_node("MatchState"):
		var ms = get_tree().get_root().get_node("MatchState")
		ms.players = players_data
		ms.local_peer_id = get_tree().get_multiplayer().get_unique_id()
	else:
		# try to set as a node on root meta as a fallback
		get_tree().root.set_meta("lobby_players", players_data)
	print("[NetworkManager] client_load_scene: scene=%s players_data=%s" % [scene_path, players_data])
	# change scene locally
	get_tree().change_scene_to_file(scene_path)


@rpc("any_peer","call_local")
func server_spawn_projectile(scene_path: String, shooter_id: int, xform: Transform3D, proj_type: int, speed: float, damage: int) -> void:
	# Clients request server to spawn an authoritative projectile; server instantiates and sets server authority
	if not is_server:
		return
	var res = ResourceLoader.load(scene_path)
	if res == null or not (res is PackedScene):
		push_error("server_spawn_projectile: failed to load scene: %s" % scene_path)
		return
	# determine server id early
	var server_id = get_tree().get_multiplayer().get_unique_id()

	# Prefer using a MultiplayerSpawner named 'ProjectileSpawner' so the engine replicates the projectile to clients.
	var current = get_tree().get_current_scene()
	var spawner: Node = null
	if current:
		spawner = _find_node_recursive(current, "ProjectileSpawner")
	if spawner != null and spawner.has_method("spawn"):
		var data = {"scene": scene_path, "transform": xform, "owner": server_id, "type": proj_type, "speed": speed, "damage": damage}
		spawner.spawn(data)
		rpc("client_play_muzzle_fx", shooter_id)
		return

	# create a unique id for this projectile so clients can remove visual copies later
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var proj_uid = str(rng.randi())

	# Fallback: instantiate locally (won't replicate to clients)
	var inst = (res as PackedScene).instantiate()
	# add before setting global transform to avoid is_inside_tree assertions
	var parent: Node = get_tree().get_current_scene()
	if parent == null:
		parent = get_tree().get_root()
	parent.add_child(inst)
	inst.set_meta("proj_uid", proj_uid)
	inst.global_transform = xform
	# set shooter info and damage on the projectile; prefer setter methods, otherwise store as meta
	if inst.has_method("set_shooter_id"):
		inst.call("set_shooter_id", shooter_id)
	else:
		inst.set_meta("shooter_id", shooter_id)

	if inst.has_method("set_damage"):
		inst.call("set_damage", damage)
	else:
		inst.set_meta("damage", damage)

	if inst.has_method("set_shell_type"):
		inst.call("set_shell_type", proj_type)
	else:
		inst.set_meta("shell_type", proj_type)
	# ensure server processes collisions: set authority to server
	if inst.has_method("set_multiplayer_authority"):
		inst.call("set_multiplayer_authority", server_id)
	elif inst.has_method("set_network_master"):
		inst.call("set_network_master", server_id)

	# already added to 'parent' above; no need to add to root again
	# set initial speed (expect projectile to implement _set_speed)
	var dir = inst.global_transform.basis.y
	if inst.has_method("_set_speed"):
		inst.call("_set_speed", dir * speed)

	# Tell clients to spawn a non-authoritative visual copy so they see the projectile (server remains authoritative for collisions)
	# Include proj_uid so clients can later remove the visual copy when server deletes authoritative projectile
	rpc("client_spawn_visual_projectile", scene_path, shooter_id, xform, proj_type, speed, damage, proj_uid)
	# Inform everyone to play muzzle effects for this shooter
	rpc("client_play_muzzle_fx", shooter_id)



@rpc("call_local")

func client_apply_damage_to_peer(target_peer_id: int, damage: int, shooter_id: int) -> void:
	# Called on all clients by the server to update a peer's tank health visualization
	# Try to find the tank node in the current scene first (safer than using root which may be a Window)
	var node_name = "Player_%s" % str(target_peer_id)
	var found: Node = null
	var current = get_tree().get_current_scene()
	if current:
		found = _find_node_recursive(current, node_name)
	else:
		# fallback: search root children recursively
		var root = get_tree().get_root()
		if root:
			found = _find_node_recursive(root, node_name)

	if found == null:
		print("[NetworkManager] client_apply_damage_to_peer: target node %s not found" % node_name)
		return

	if found and found.has_method("rpc_apply_damage"):
		found.call("rpc_apply_damage", damage, shooter_id)


@rpc("call_remote")
func client_spawn_visual_projectile(scene_path: String, shooter_id: int, xform: Transform3D, proj_type: int, speed: float, damage: int, proj_uid: String) -> void:
	# Clients spawn a local visual-only projectile (non-authoritative) when instructed by the server.
	var res = ResourceLoader.load(scene_path)
	if res == null or not (res is PackedScene):
		return
	var inst = (res as PackedScene).instantiate()
	# attach to current scene (or root) before setting global transform to avoid is_inside_tree asserts
	var parent: Node = get_tree().get_current_scene()
	if parent == null:
		parent = get_tree().get_root()
	parent.add_child(inst)
	if inst is Node3D:
		inst.global_transform = xform
	# attach visual metadata so any local code can read it
	inst.set_meta("shooter_id", shooter_id)
	inst.set_meta("damage", damage)
	inst.set_meta("shell_type", proj_type)
	inst.set_meta("proj_uid", proj_uid)

	# already added to 'parent' above; no need to add to root again
	if inst.has_method("_set_speed"):
		inst.call("_set_speed", inst.global_transform.basis.y * speed)


@rpc("call_local")
func client_play_muzzle_fx(shooter_id: int) -> void:
	var current = get_tree().get_current_scene()
	var node: Node = null
	if current:
		node = _find_node_recursive(current, "Player_%s" % str(shooter_id))
	if node == null:
		node = _find_node_recursive(get_tree().get_root(), "Player_%s" % str(shooter_id))
	if node and node.has_method("play_muzzle_fx"):
		node.call("play_muzzle_fx")


@rpc("call_remote")
func client_remove_visual_projectile(proj_uid: String) -> void:
	# find visual projectile by proj_uid meta and remove it
	var root = get_tree().get_current_scene()
	if root == null:
		root = get_tree().get_root()
	var node = _find_node_by_meta(root, "proj_uid", proj_uid)
	if node != null:
		node.queue_free()
	else:
		# as a fallback try searching root
		var fallback = _find_node_by_meta(get_tree().get_root(), "proj_uid", proj_uid)
		if fallback != null:
			fallback.queue_free()


@rpc("call_remote")
func client_spawn_explosion(position: Vector3, _shell_type: int) -> void:
	# Spawn explosion effect on clients (visual only)
	var explosion_scene = ResourceLoader.load("res://game/effects/explosion.tscn")
	if explosion_scene == null or not (explosion_scene is PackedScene):
		return
	var item = (explosion_scene as PackedScene).instantiate()
	# attach to current scene (or root) before setting global transform
	var parent: Node = get_tree().get_current_scene()
	if parent == null:
		parent = get_tree().get_root()
	parent.add_child(item)
	if item is Node3D:
		item.global_transform = Transform3D(item.global_transform.basis, position)
	if item.has_method("explosion"):
		item.explosion()


func _find_node_recursive(root: Node, target_name: String) -> Node:
	# simple DFS search for node name (works even if engine's find_node isn't available)
	if root == null:
		return null
	if str(root.name) == str(target_name):
		return root
	for child in root.get_children():
		if child is Node:
			var res = _find_node_recursive(child, target_name)
			if res != null:
				return res
	return null


func _find_node_by_meta(root: Node, key: String, value) -> Node:
	if root == null:
		return null
	if root.has_meta(key) and root.get_meta(key) == value:
		return root
	for child in root.get_children():
		if child is Node:
			var res = _find_node_by_meta(child, key, value)
			if res != null:
				return res
	return null
