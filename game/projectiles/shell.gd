extends RigidBody3D


@export_enum("AP","HE") var shell_type:int
@onready var ray_cast_3d: RayCast3D = $RayCast3D
@export var pen = 100
@export var shooter_id: int = 0
@export var damage: int = 25
@export var speed: float = 100.0
const EXPLOSION = preload("res://game/effects/explosion.tscn")

func _set_speed(dir):
	apply_central_impulse(dir)

func _ready() -> void:
	# If this projectile was spawned via a spawner or via RPC, parameters may be in meta
	if has_meta("shooter_id"):
		shooter_id = int(get_meta("shooter_id"))
	if has_meta("damage"):
		damage = int(get_meta("damage"))
	if has_meta("speed"):
		speed = float(get_meta("speed"))


func _is_authority() -> bool:
	var mp = get_tree().get_multiplayer()
	var my_id = mp.get_unique_id()
	if has_method("get_multiplayer_authority"):
		return int(call("get_multiplayer_authority")) == int(my_id)
	if has_method("get_network_master"):
		return int(call("get_network_master")) == int(my_id)
	return true

func _on_body_entered(body: Node) -> void:
	# keep existing stub for contact handling if used
	call_deferred("set_contact_monitor", false)


func _physics_process(delta: float) -> void:
	# Only process collisions and damage on the authority peer (server)
	if not _is_authority():
		return

	if ray_cast_3d.is_colliding():
		var hit = ray_cast_3d.get_collider()
		# try to apply damage: if the hit node exposes `take_damage` or has a player owner meta
		var target_peer_id = null
		if hit.has_meta("owner_id"):
			target_peer_id = hit.get_meta("owner_id")
		elif hit.name.begins_with("Player_"):
			var parts = hit.name.split("_")
			if parts.size() >= 2:
				target_peer_id = int(parts[1])

		# Inform NetworkManager (server) to broadcast damage to clients
		if target_peer_id != null:
			if get_tree().get_root().has_node("NetworkManager"):
				var nm = get_tree().get_root().get_node("NetworkManager")
				# Server instructs all clients to apply damage to the owner of the hit tank
				nm.rpc("client_apply_damage_to_peer", int(target_peer_id), int(damage), int(shooter_id))

		if hit and hit.has_method("make_hit_decal"):
			hit.make_hit_decal(ray_cast_3d.get_collision_point(), global_position - ray_cast_3d.get_collision_point())
			if shell_type == 1:
				if EXPLOSION:
					var item = EXPLOSION.instantiate()
					get_tree().root.add_child(item)
					var pos = ray_cast_3d.get_collision_point() + global_position - ray_cast_3d.get_collision_point()
					item.global_position = pos
					if item.has_method("explosion"):
						item.explosion()
					# also notify clients to spawn visual explosion at that position
					if get_tree().get_root().has_node("NetworkManager"):
						var nm = get_tree().get_root().get_node("NetworkManager")
						# run on clients only
						nm.rpc("client_spawn_explosion", pos, shell_type)
						# instruct clients to remove the visual projectile copy with the same proj_uid
						if has_meta("proj_uid"):
							var pu = get_meta("proj_uid")
							nm.rpc("client_remove_visual_projectile", pu)
		queue_free()
