extends Control

var new_game_button: Button
var continue_button: Button
var settings_button: Button
var quit_button: Button

func _ready() -> void:
	# Get node references
	new_game_button = get_node_or_null("VBoxContainer/NewGameButton")
	continue_button = get_node_or_null("VBoxContainer/ContinueButton")
	settings_button = get_node_or_null("VBoxContainer/SettingsButton")
	quit_button = get_node_or_null("VBoxContainer/QuitButton")
	
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
		continue_button.disabled = not SaveManager.has_save_file()
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _on_new_game_pressed() -> void:
	GameManager.start_new_game()

func _on_continue_pressed() -> void:
	if SaveManager.load_game():
		GameManager.start_new_game()
	else:
		print("Failed to load save file")

func _on_settings_pressed() -> void:
	print("Settings menu not yet implemented")

func _on_quit_pressed() -> void:
	get_tree().quit()
