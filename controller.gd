extends Node

var truck_ammo = 0
var max_ammo = 100
var shift_points = 3

@onready var zones:Array = get_tree().get_nodes_in_group("zones")
@onready var current_front:Node3D = zones[shift_points]

func next_point():
	print(current_front.get_parent(),"  ",shift_points)
	shift_points -= 1
	if shift_points < 0:
		print("GAME OVER")
		return
	zones[shift_points].active_front = true
	current_front = zones[shift_points]
	pass
