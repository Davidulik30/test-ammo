extends CanvasLayer


func _ready() -> void:
	if not is_multiplayer_authority():
		# Если это чужой игрок (кукла), то его интерфейс нам не нужен.
		# Самый правильный способ - полностью удалить его CanvasLayer,
		# чтобы он не тратил ресурсы.
		queue_free()
