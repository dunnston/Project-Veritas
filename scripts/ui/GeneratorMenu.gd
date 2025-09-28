extends Control
class_name GeneratorMenu

@onready var title_label: Label = $GeneratorPanel/VBoxContainer/TitleBar/TitleLabel
@onready var close_button: Button = $GeneratorPanel/VBoxContainer/TitleBar/CloseButton
@onready var generator_icon: TextureRect = $GeneratorPanel/VBoxContainer/MainContainer/StatusPanel/StatusContainer/GeneratorIcon
@onready var status_label: Label = $GeneratorPanel/VBoxContainer/MainContainer/StatusPanel/StatusContainer/StatusLabel
@onready var time_label: Label = $GeneratorPanel/VBoxContainer/MainContainer/StatusPanel/StatusContainer/TimeLabel
@onready var crank_button: Button = $GeneratorPanel/VBoxContainer/MainContainer/ButtonContainer/CrankButton
@onready var move_button: Button = $GeneratorPanel/VBoxContainer/MainContainer/ButtonContainer/MoveButton
@onready var destroy_button: Button = $GeneratorPanel/VBoxContainer/MainContainer/ButtonContainer/DestroyButton

var current_generator: HandCrankGeneratorBuilding = null

static var instance: GeneratorMenu

func _ready():
	instance = self
	visible = false
	
	# Connect button signals if not already connected in the scene
	if close_button and not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)
	if crank_button and not crank_button.pressed.is_connected(_on_crank_button_pressed):
		crank_button.pressed.connect(_on_crank_button_pressed)
	if move_button and not move_button.pressed.is_connected(_on_move_button_pressed):
		move_button.pressed.connect(_on_move_button_pressed)
	if destroy_button and not destroy_button.pressed.is_connected(_on_destroy_button_pressed):
		destroy_button.pressed.connect(_on_destroy_button_pressed)
	
	# Load generator icon
	var icon_path = "res://assets/sprites/items/generator2.png"
	if ResourceLoader.exists(icon_path):
		generator_icon.texture = load(icon_path)
	
	print("GeneratorMenu ready and initialized")

func _process(_delta: float):
	# Update display every frame if menu is open and generator exists
	if visible and current_generator:
		update_generator_info()

func open_generator_menu(generator: HandCrankGeneratorBuilding):
	current_generator = generator
	visible = true
	update_generator_info()

func update_generator_info():
	if not current_generator:
		return
	
	# Update status
	if current_generator.is_running:
		status_label.text = "Status: Running"
		status_label.add_theme_color_override("font_color", Color.GREEN)
		crank_button.text = "RUNNING"
		crank_button.disabled = true
	else:
		status_label.text = "Status: Not Running"
		status_label.add_theme_color_override("font_color", Color.RED)
		crank_button.text = "CRANK (4h)"
		crank_button.disabled = false
	
	# Update remaining time
	time_label.text = "Remaining Time: " + current_generator.get_remaining_time_text()

func _on_close_button_pressed():
	visible = false
	current_generator = null

func _on_crank_button_pressed():
	if not current_generator:
		return
	
	if current_generator.crank_generator():
		print("Generator cranked successfully!")
		update_generator_info()
	else:
		print("Generator is already running!")

func _on_move_button_pressed():
	if current_generator:
		current_generator.move_generator()
		visible = false
		current_generator = null

func _on_destroy_button_pressed():
	if current_generator:
		current_generator.destroy_generator()
		visible = false
		current_generator = null
