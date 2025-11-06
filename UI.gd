extends Control

@onready var label = $Label
@onready var label_current_front = $Label2
func _process(delta: float) -> void:
	label.text = "Ammo :"+ str(Controller.truck_ammo)
	if Controller.current_front:
		label_current_front.text = "current front ammo :"+ str(Controller.current_front.current_ammo)
