extends Control

# Attach to Tank Select root Control node.
# Expected children (example):
# - VBoxContainer "TanksContainer" where buttons for tanks are created
# - VBoxContainer "PlayersList" where connected players are listed
# - Button "StartButton" (visible/enabled only to host)

@onready var tanks_container := $TanksContainer
@onready var players_list := $PlayersList
@onready var start_button := $StartButton
# NetworkManager is an Autoload; call it directly as a global singleton

# list of available tank ids/names — adapt to your project
var tanks := ["LemanRuss", "Predator", "Scout"]

func _ready():
	# connect to the Autoloaded NetworkManager directly
	if Engine.get_main_loop().get_root().has_node("NetworkManager"):
		NetworkManager.connect("player_list_updated", Callable(self, "_on_player_list_updated"))
		# enable start button only for server
		start_button.disabled = not NetworkManager.is_server
		start_button.pressed.connect(Callable(self, "_on_start_pressed"))
	else:
		push_warning("Autoload 'NetworkManager' not found on the root — ensure it's added in Project Settings -> Autoloads.")
	_build_tank_buttons()

func _build_tank_buttons() -> void:
	for c in tanks_container.get_children():
		c.queue_free()
	for t in tanks:
		var btn = Button.new()
		btn.text = t
		btn.name = t
		btn.pressed.connect(Callable(self, "_on_tank_selected").bind(t))
		tanks_container.add_child(btn)

func _on_tank_selected(tank_name: String) -> void:
	# Use Autoload NetworkManager directly
	print("[TankSelect] _on_tank_selected: %s" % tank_name)
	if not Engine.get_main_loop().get_root().has_node("NetworkManager"):
		push_error("NetworkManager Autoload missing; cannot set tank")
		return
	if NetworkManager.is_server:
		# server can set directly
		print("[TankSelect] calling NetworkManager.server_set_tank locally")
		NetworkManager.server_set_tank(tank_name)
	else:
		print("[TankSelect] rpc_id -> request server to set tank: %s" % tank_name)
		# send the RPC to the NetworkManager autoload on the server
		if Engine.get_main_loop().get_root().has_node("NetworkManager"):
			NetworkManager.rpc_id(1, "server_set_tank", tank_name)
		else:
			# fallback: try calling rpc_id on this node targeting the NetworkManager path explicitly
			rpc_id(1, "/root/NetworkManager:server_set_tank", tank_name)

func _on_player_list_updated(players: Dictionary) -> void:
	for c in players_list.get_children():
		c.queue_free()
	for id in players.keys():
		var info = players[id]
		var label = Label.new()
		var pname = info.get("name", "Player_%d" % id)
		var tank = info.get("tank", null)
		if tank == null:
			tank = "(no tank)"
		label.text = "%s — %s" % [pname, tank]
		players_list.add_child(label)

func _on_start_pressed() -> void:
	print("[TankSelect] _on_start_pressed; is_server=%s" % NetworkManager.is_server)
	if Engine.get_main_loop().get_root().has_node("NetworkManager") and NetworkManager.is_server:
		print("[TankSelect] calling NetworkManager.server_request_start()")
		NetworkManager.server_request_start()
	else:
		push_warning("Only host can start the game")
