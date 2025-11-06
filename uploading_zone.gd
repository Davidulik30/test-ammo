extends Area3D

var truck_entered = false

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("truck"):
		print("JOPA")
		truck_entered = true
	pass # Replace with function body.


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("truck"):
		truck_entered = false
	pass # Replace with function body.

func _process(delta: float) -> void:
	if truck_entered and Controller.truck_ammo<=Controller.max_ammo:
		Controller.truck_ammo +=1
	pass
