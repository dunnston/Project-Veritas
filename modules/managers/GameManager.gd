extends Node

class_name GameManagerModule

signal game_state_changed(new_state: GameState)
signal game_paused(is_paused: bool)

enum GameState {
	MAIN_MENU,
	TUTORIAL,
	IN_GAME,
	BUILD_MODE,
	INVENTORY,
	PAUSED,
	GAME_OVER
}

var current_state: GameState = GameState.MAIN_MENU
var is_paused: bool = false
var game_time: float = 0.0
var player_node: Node = null
var world_node: Node = null
var tutorial_completed: bool = false
var instance_id: int

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	instance_id = randi()
	# Wait a frame to ensure other managers are ready
	await get_tree().process_frame
	print("GameManager initialized")

func _process(delta: float) -> void:
	if not is_paused and current_state == GameState.IN_GAME:
		game_time += delta

func change_state(new_state: GameState) -> void:
	var old_state = current_state
	current_state = new_state
	print("Changing game state from %d to %d" % [old_state, new_state])
	game_state_changed.emit(new_state)
	print("Game state changed successfully")

func toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused
	game_paused.emit(is_paused)
	
	if is_paused:
		change_state(GameState.PAUSED)
	else:
		change_state(GameState.IN_GAME)

func pause_game() -> void:
	if not is_paused:
		is_paused = true
		get_tree().paused = true
		game_paused.emit(true)

func resume_game() -> void:
	if is_paused:
		is_paused = false
		get_tree().paused = false
		game_paused.emit(false)

func start_new_game() -> void:
	game_time = 0.0
	is_paused = false
	
	if not tutorial_completed:
		change_state(GameState.TUTORIAL)
		get_tree().change_scene_to_file("res://scenes/levels/Bedroom.tscn")
	else:
		change_state(GameState.IN_GAME)
		get_tree().change_scene_to_file("res://scenes/GameWorld.tscn")
		
func start_tutorial() -> void:
	game_time = 0.0
	is_paused = false
	change_state(GameState.TUTORIAL)
	get_tree().change_scene_to_file("res://scenes/levels/Bedroom.tscn")
	
func complete_tutorial() -> void:
	tutorial_completed = true
	SaveManager.save_settings()
	start_new_game()

func load_main_world() -> void:
	"""Called when tutorial is completed to transition to main game world"""
	tutorial_completed = true
	change_state(GameState.IN_GAME) 
	get_tree().change_scene_to_file("res://scenes/GameWorld.tscn")

func return_to_menu() -> void:
	change_state(GameState.MAIN_MENU)
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

# Enhanced scene transition with spawn point support
func change_scene(scene_path: String, spawn_point_name: String = ""):
	print("GameManager: Changing scene to %s (spawn: %s)" % [scene_path, spawn_point_name])
	
	# Store spawn point for the new scene to use
	if spawn_point_name != "":
		var spawn_data = {
			"spawn_point": spawn_point_name,
			"previous_scene": get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
		}
		# Store in a way the new scene can access it
		get_tree().set_meta("spawn_data", spawn_data)
	
	# Change scene
	var result = get_tree().change_scene_to_file(scene_path)
	if result != OK:
		print("Error: Failed to change scene to %s" % scene_path)

func register_player(player: Node) -> void:
	player_node = player
	print("Player registered with GameManager")

func register_world(world: Node) -> void:
	world_node = world
	print("World registered with GameManager")

func get_formatted_time() -> String:
	var hours = int(game_time / 3600)
	var minutes = int((game_time - hours * 3600) / 60)
	var seconds = int(game_time - hours * 3600 - minutes * 60)
	return "%02d:%02d:%02d" % [hours, minutes, seconds]

# DEBUG: Helper function that can be called by other systems
func debug_add_consumables() -> void:
	print("DEBUG: Adding food and water items for testing")
	# Add items to the InventorySystem (which the UI uses)
	InventorySystem.add_item("FOOD", 5)
	InventorySystem.add_item("WATER", 5)
	print("DEBUG: Added 5 FOOD and 5 WATER to inventory")

# DEBUG: Setup hotbar with test items
func debug_setup_hotbar() -> void:
	print("DEBUG: Setting up hotbar with test items")
	
	# Add some test items to inventory first
	InventorySystem.add_item("WOOD", 50)
	InventorySystem.add_item("SCRAP_METAL", 30)
	InventorySystem.add_item("METAL_SHEETS", 10)
	
	if InventorySystem:
		InventorySystem.add_item("OXYGEN_TANK", 2)
		InventorySystem.add_item("HAND_CRANK_GENERATOR", 1)
		InventorySystem.add_item("SCRAP_PICKAXE", 1)
		InventorySystem.add_item("CROWBAR", 1)
	
	# Get HUD and add items to hotbar
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("add_item_to_hotbar"):
		hud.add_item_to_hotbar("WOOD", 0)
		hud.add_item_to_hotbar("SCRAP_METAL", 1)
		hud.add_item_to_hotbar("OXYGEN_TANK", 2)
		hud.add_item_to_hotbar("HAND_CRANK_GENERATOR", 3)
		hud.add_item_to_hotbar("SCRAP_PICKAXE", 4)
		hud.add_item_to_hotbar("CROWBAR", 5)
		print("DEBUG: Hotbar populated with test items")
	else:
		print("DEBUG: Could not find HUD to populate hotbar")

# DEBUG: Test player stat changes for UI
func debug_test_player_stats() -> void:
	print("DEBUG: Testing player stat changes")
	
	if not player_node:
		print("DEBUG: No player node found")
		return
	
	print("DEBUG: Player node type: %s" % player_node.get_class())
	print("DEBUG: Player node script: %s" % str(player_node.get_script()))
	
	# Test stat modifications if methods exist
	if player_node.has_method("modify_health"):
		player_node.modify_health(-10)  # Reduce health by 10
		print("DEBUG: Reduced health by 10")
	
	if player_node.has_method("modify_energy"):
		player_node.modify_energy(-15)  # Reduce energy by 15
		print("DEBUG: Reduced energy by 15")
		
	if player_node.has_method("modify_hunger"):
		player_node.modify_hunger(-20)  # Reduce hunger by 20
		print("DEBUG: Reduced hunger by 20")
		
	if player_node.has_method("modify_thirst"):
		player_node.modify_thirst(-25)  # Reduce thirst by 25
		print("DEBUG: Reduced thirst by 25")
	
	print("DEBUG: Player stat test completed")
