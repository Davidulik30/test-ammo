extends Area3D

var current_ammo = 100
@export var active_front = false
var truck_in = false 

func _process(delta: float) -> void:
	if active_front:
		current_ammo -= 0.1
		if current_ammo <=1:
			Controller.next_point()
			queue_free()
		if truck_in and Controller.truck_ammo>0:
			current_ammo += 1
			Controller.truck_ammo -=1


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("truck"):
		truck_in = true
	pass # Replace with function body.


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("truck"):
		truck_in = false 
	pass # Replace with function body.
