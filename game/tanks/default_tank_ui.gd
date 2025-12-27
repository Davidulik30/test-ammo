extends CanvasLayer

@onready var aim: TextureRect = $aim
@onready var sightaim: TextureRect = $sightaim
@onready var zoom: Label = $zoom
@onready var reload_label: Label = $ReloadLabel
@onready var control: Control = $Control
@onready var ammo_container: HBoxContainer = $Ammocontainer
var current_shell: = 0

func _ready() -> void:
	if !is_multiplayer_authority():return
	
	
	var shells = get_parent().shell_types
	for i in shells:
		var shell = TextureRect.new()
		if i.icon == null:
			shell.texture = load("res://icon.svg")
		shell.texture = i.icon
		$Ammocontainer.add_child(shell)
		pass

func change_shell(shell):
	current_shell = shell
	pass
