extends Control

# UI для выбора команды и танка перед началом игры
# Игроки выбирают команду 1 или 2, затем танк, и нажимают "Готов"
# Игра начинается автоматически когда все игроки готовы

@onready var team1_button: Button = $TeamsContainer/Team1Panel/Team1VBox/Team1Button
@onready var team2_button: Button = $TeamsContainer/Team2Panel/Team2VBox/Team2Button
@onready var team1_players: VBoxContainer = $TeamsContainer/Team1Panel/Team1VBox/Team1Players
@onready var team2_players: VBoxContainer = $TeamsContainer/Team2Panel/Team2VBox/Team2Players
@onready var tanks_container: HBoxContainer = $BottomPanel/TankSelectPanel/TanksContainer
@onready var ready_button: Button = $BottomPanel/ReadyButton
@onready var status_label: Label = $StatusLabel

# Доступные танки
var tanks := []

func _refresh_tank_list() -> void:
	# get names from TankRegistry autoload
	if Engine.get_main_loop().get_root().has_node("TankRegistry"):
		var names = TankRegistry.get_tank_names()
		if names.size() > 0:
			tanks = names
			# rebuild buttons if UI already created
			if is_inside_tree():
				_build_tank_buttons()
			return
	# fallback default list
	tanks = ["Tank", "Predator", "LemanRus", "Scouter"]
var my_team: int = 0
var my_tank: String = ""
var is_ready: bool = false

func _ready() -> void:
	# Подключаем сигналы кнопок команд
	team1_button.pressed.connect(_on_team1_pressed)
	team2_button.pressed.connect(_on_team2_pressed)
	ready_button.pressed.connect(_on_ready_pressed)
	
	# Подключаем к NetworkManager
	if Engine.get_main_loop().get_root().has_node("NetworkManager"):
		NetworkManager.connect("player_list_updated", Callable(self, "_on_player_list_updated"))
	else:
		push_warning("NetworkManager Autoload не найден!")
	
	# Load tanks from TankRegistry (if available)
	_refresh_tank_list()
	# Создаём кнопки танков
	_build_tank_buttons()
	
	# Обновляем UI
	_update_ready_button()
	
	# Запрашиваем текущий список игроков
	if Engine.get_main_loop().get_root().has_node("NetworkManager"):
		_on_player_list_updated(NetworkManager.players)

func _build_tank_buttons() -> void:
	# Очищаем старые кнопки
	for c in tanks_container.get_children():
		c.queue_free()
	
	# Создаём кнопку для каждого танка
	for t in tanks:
		var btn := Button.new()
		btn.text = t
		btn.name = t
		btn.toggle_mode = true
		btn.pressed.connect(_on_tank_selected.bind(t))
		tanks_container.add_child(btn)

func _on_team1_pressed() -> void:
	_select_team(1)

func _on_team2_pressed() -> void:
	_select_team(2)

func _select_team(team: int) -> void:
	my_team = team
	is_ready = false
	
	# Отправляем на сервер
	if NetworkManager.is_server:
		NetworkManager.server_set_team(team)
	else:
		NetworkManager.rpc_id(1, "server_set_team", team)
	
	_update_team_buttons()
	_update_ready_button()

func _on_tank_selected(tank_name: String) -> void:
	my_tank = tank_name
	is_ready = false
	
	# Обновляем выделение кнопок
	for btn in tanks_container.get_children():
		if btn is Button:
			btn.button_pressed = (btn.name == tank_name)
	
	# Отправляем на сервер
	if NetworkManager.is_server:
		NetworkManager.server_set_tank(tank_name)
	else:
		NetworkManager.rpc_id(1, "server_set_tank", tank_name)
	
	_update_ready_button()

func _on_ready_pressed() -> void:
	if my_team == 0:
		status_label.text = "Сначала выберите команду!"
		return
	if my_tank == "":
		status_label.text = "Сначала выберите танк!"
		return
	
	is_ready = not is_ready
	
	# Отправляем на сервер
	if NetworkManager.is_server:
		NetworkManager.server_set_ready(is_ready)
	else:
		NetworkManager.rpc_id(1, "server_set_ready", is_ready)
	
	_update_ready_button()

func _on_player_list_updated(players: Dictionary) -> void:
	# Очищаем списки команд
	for c in team1_players.get_children():
		c.queue_free()
	for c in team2_players.get_children():
		c.queue_free()
	
	var ready_count := 0
	var total_count := players.size()
	
	# Заполняем списки игроков по командам
	for id in players.keys():
		var info: Dictionary = players[id]
		var pname: String = info.get("name", "Player_%d" % id)
		var tank = info.get("tank", null)
		var team: int = info.get("team", 0)
		var ready: bool = info.get("ready", false)
		
		if ready:
			ready_count += 1
		
		# Формируем текст для игрока
		var player_text := pname
		if tank != null and tank != "":
			player_text += " [%s]" % tank
		if ready:
			player_text += " ✓"
		
		var label := Label.new()
		label.text = player_text
		
		# Добавляем в нужную команду
		if team == 1:
			team1_players.add_child(label)
		elif team == 2:
			team2_players.add_child(label)
		else:
			# Игрок ещё не выбрал команду - показываем в обеих с пометкой
			label.text = pname + " (не выбрал)"
			label.modulate = Color(0.6, 0.6, 0.6)
			# Добавляем только в первую команду для отображения
			team1_players.add_child(label)
	
	# Обновляем статус
	if total_count > 0:
		status_label.text = "Готовы: %d / %d" % [ready_count, total_count]
	else:
		status_label.text = "Ожидание игроков..."
	
	# Синхронизируем локальное состояние с сервером
	var my_id := get_tree().get_multiplayer().get_unique_id()
	if players.has(my_id):
		var my_info: Dictionary = players[my_id]
		my_team = my_info.get("team", 0)
		my_tank = my_info.get("tank", "") if my_info.get("tank", null) != null else ""
		is_ready = my_info.get("ready", false)
		_update_team_buttons()
		_update_tank_buttons()
		_update_ready_button()

func _update_team_buttons() -> void:
	team1_button.text = "В команде 1" if my_team == 1 else "Присоединиться"
	team2_button.text = "В команде 2" if my_team == 2 else "Присоединиться"
	team1_button.disabled = (my_team == 1)
	team2_button.disabled = (my_team == 2)

func _update_tank_buttons() -> void:
	for btn in tanks_container.get_children():
		if btn is Button:
			btn.button_pressed = (btn.name == my_tank)

func _update_ready_button() -> void:
	if is_ready:
		ready_button.text = "Отмена"
		ready_button.modulate = Color(1, 0.5, 0.5)
	else:
		ready_button.text = "Готов"
		ready_button.modulate = Color(1, 1, 1)
	
	# Деактивируем если не выбраны команда и танк
	ready_button.disabled = (my_team == 0 or my_tank == "")
