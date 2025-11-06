extends Node

# Simple holder for match data. Recommended to add this as an Autoload
# (Project Settings -> Autoload) with the name "MatchState" so it survives
# scene changes and is accessible from the game scene.

var players: Dictionary = {} # peer_id -> {name, tank}
var local_peer_id: int = 0

func clear() -> void:
	players.clear()
	local_peer_id = 0
