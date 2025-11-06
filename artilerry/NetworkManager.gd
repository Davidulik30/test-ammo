# NetworkManager.gd
extends Node

# Сигнал для обновления UI в лобби, когда список игроков изменился
signal player_list_changed

const DEFAULT_PORT = 8910
var player_name : String = "Player"

# Словарь для хранения информации об игроках: {id: "имя"}
var players = {}

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(new_player_name: String):
	player_name = new_player_name
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(DEFAULT_PORT)
	if error != OK:
		print("Не удалось создать сервер.")
		return

	multiplayer.multiplayer_peer = peer
	print("Сервер создан, ожидаем игроков...")
	_add_player_info(multiplayer.get_unique_id(), player_name)

func join_game(ip_address: String, new_player_name: String):
	player_name = new_player_name

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_address, DEFAULT_PORT)
	if error != OK:
		print("Не удалось подключиться к серверу.")
		return
		
	multiplayer.multiplayer_peer = peer
	print("Подключаемся к серверу...")

func _on_player_connected(id: int):
	print("Игрок {id} подключился.")
	# <<< ИСПРАВЛЕНО: Новый синтаксис RPC
	register_player.rpc_id(id, player_name)

# RPC-функция, вызываемая СЕРВЕРОМ на КЛИЕНТЕ
@rpc("any_peer", "call_local")
func register_player(host_name: String):
	_add_player_info(1, host_name)
	# <<< ИСПРАВЛЕНО: Новый синтаксис RPC
	send_player_info.rpc_id(1, player_name)

# RPC-функция, вызываемая КЛИЕНТОМ на СЕРВЕРЕ
# <<< ИСПРАВЛЕНО: Разрешаем вызов любому пиру, а не только "авторитету"
@rpc("any_peer", "call_local")
func send_player_info(new_player_name: String):
	var id = multiplayer.get_remote_sender_id()
	_add_player_info(id, new_player_name)

	for player_id in players:
		# <<< ИСПРАВЛЕНО: Новый синтаксис RPC
		update_player_list.rpc_id(player_id, players)

# RPC-функция, вызываемая СЕРВЕРОМ на ВСЕХ КЛИЕНТАХ
@rpc("any_peer", "call_local")
func update_player_list(updated_players: Dictionary):
	players = updated_players
	player_list_changed.emit()

func _on_player_disconnected(id: int):
	print("Игрок {id} отключился.")
	if players.has(id):
		players.erase(id)
		# Оповещаем остальных игроков об изменении
		for player_id in players:
			update_player_list.rpc_id(player_id, players)
	player_list_changed.emit() # Обновляем UI локально

func _add_player_info(id: int, p_name: String): # <<< ИСПРАВЛЕНО: Переименовано, чтобы избежать предупреждения
	players[id] = p_name
	player_list_changed.emit()

@rpc("any_peer", "call_local","reliable")
func start_game():
	get_tree().change_scene_to_file("res://Net/Game.tscn")

func _on_connected_to_server():
	print("Успешно подключен к серверу!")

func _on_connection_failed():
	print("Не удалось подключиться.")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	print("Отключен от сервера.")
	multiplayer.multiplayer_peer = null
	players.clear()
	player_list_changed.emit()
	get_tree().change_scene_to_file("res://Lobby.tscn")
