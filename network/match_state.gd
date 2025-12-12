extends Node

# Simple holder for match data. Recommended to add this as an Autoload
# (Project Settings -> Autoload) with the name "MatchState" so it survives
# scene changes and is accessible from the game scene.

# peer_id -> {name: String, tank: String, team: int (1 or 2), ready: bool}
var players: Dictionary = {}
var local_peer_id: int = 0

func clear() -> void:
	players.clear()
	local_peer_id = 0

func get_team_players(team: int) -> Array:
	var result := []
	for id in players.keys():
		if players[id].get("team", 0) == team:
			result.append({"id": id, "data": players[id]})
	return result

func all_players_ready() -> bool:
	if players.size() == 0:
		return false
	for id in players.keys():
		if not players[id].get("ready", false):
			return false
	return true
