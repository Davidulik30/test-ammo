extends Node3D

@onready var left_truck: MeshInstance3D = $Tank/Body/LeftTruck
@onready var right_truck: MeshInstance3D = $Tank/Body/RightTruck

@onready var left_gun: MeshInstance3D = $Tank/Body/LeftTruck/LeftGunPod/LeftGun
@onready var right_gun: MeshInstance3D = $Tank/Body/RightTruck/RightGunPod/RightGun

@onready var turret: MeshInstance3D = $Tank/Body/Turret
@onready var dulo: MeshInstance3D = $Tank/Body/Turret/Barrel/Dulo


func _ready() -> void:
	
	pass

func _process(delta: float) -> void:
	pass
