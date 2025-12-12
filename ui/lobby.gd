extends Control

# Attach this script to your lobby UI root Control node.
# Expected children (example names):
# - LineEdit named "IPLine"
# - LineEdit named "PortLine"
# - Button named "HostButton"
# - Button named "JoinButton"
# - Button named "QuitButton"
# - Label named "StatusLabel"
# - Node named "NetworkManager" with network_manager.gd attached

@onready var ip_line := $IPLine
@onready var port_line := $PortLine
@onready var host_btn := $HostButton
@onready var join_btn := $JoinButton
@onready var quit_btn := $QuitButton
@onready var status_label := $StatusLabel

func _ready():
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	# listen to network events
	NetworkManager.connect("connected", Callable(self, "_on_connected"))
	NetworkManager.connect("disconnected", Callable(self, "_on_disconnected"))
	NetworkManager.connect("connection_failed", Callable(self, "_on_connection_failed"))

func _on_host_pressed() -> void:
	var port = int(port_line.text) if port_line.text != "" else 7777
	NetworkManager.host(port)
	status_label.text = "Hosting on port %d" % port
	# proceed to tank selection for the host
	_go_to_tank_select()

func _on_join_pressed() -> void:
	var ip = ip_line.text if ip_line.text != "" else "127.0.0.1"
	var port = int(port_line.text) if port_line.text != "" else 7777
	NetworkManager.join(ip, port)
	status_label.text = "Connecting to %s:%d..." % [ip, port]

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_connected() -> void:
	status_label.text = "Connected"
	_go_to_tank_select()

func _on_disconnected() -> void:
	status_label.text = "Disconnected"

func _on_connection_failed() -> void:
	status_label.text = "Connection failed"

func _go_to_tank_select() -> void:
	# Replace with actual change_scene_to_file or show the TankSelect UI
	var path = "res://ui/tank_select.tscn"
	if FileAccess.file_exists(path):
		# Try to obtain the SceneTree robustly. get_tree() can be null if this node
		# was freed or not yet in the tree at the time of the call. Use Engine.get_main_loop()
		# as a reliable fallback, and call_deferred to avoid timing issues.
		var st = null
		if has_method("get_tree"):
			st = get_tree()
		if st == null:
			st = Engine.get_main_loop()
		if st and st is SceneTree:
			# Use deferred call so scene change happens safely after current frame.
			st.call_deferred("change_scene_to_file", path)
		else:
			push_error("Couldn't obtain a SceneTree to change scene to %s" % path)
	else:
		push_warning("Tank select scene not found at %s — create it and try again." % path)
