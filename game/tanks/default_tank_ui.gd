extends CanvasLayer

@onready var aim: TextureRect = $aim
@onready var sightaim: TextureRect = $sightaim
@onready var zoom: Label = $zoom
@onready var reload_label: Label = $ReloadLabel
@onready var control: Control = $Control
@onready var ammo_container: HBoxContainer = $Ammocontainer
var current_shell: int = 0
var _ammo_slots: Array = []

func _ready() -> void:
	if !is_multiplayer_authority():
		return

	var shells = get_parent().shell_types
	for idx in range(shells.size()):
		var i = shells[idx]
		var shell = TextureRect.new()
		# fallback icon
		if i.icon == null:
			shell.texture = load("res://icon.svg")
		else:
			shell.texture = i.icon
		shell.name = str(idx)
		shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ammo_container.add_child(shell)
		_ammo_slots.append(shell)

	# ensure selection visual is correct initially
	_update_selection()

func change_shell(shell):
	current_shell = int(shell)
	_update_selection()

func _update_selection() -> void:
	# Highlight selected slot
	for i in range(_ammo_slots.size()):
		var node: TextureRect = _ammo_slots[i]
		if i == current_shell:
			node.modulate = Color(1.0, 0.85, 0.0, 1.0) # warm highlight
		else:
			node.modulate = Color(1,1,1,1)
