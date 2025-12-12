extends StaticBody3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

@export var decal_scene: PackedScene = preload("res://game/effects/impact_decal.tscn")

func make_hit_decal(global_hit: Vector3, global_normal: Vector3):
	if not decal_scene:
		push_warning("Не задана сцена декали (decal_scene)")
		return

	var decal = decal_scene.instantiate()
	get_tree().current_scene.add_child(decal)

	# Ставим декаль в точку попадания
	decal.global_position = global_hit + global_normal * 0.05
#
	## Добавляем немного случайного вращения, чтобы следы не повторялись
	decal.rotate_object_local(Vector3(0, 0, 1), randf() * TAU)


	print("Декаль создана в позиции:", global_hit)
