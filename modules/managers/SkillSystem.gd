extends Node

class_name SkillSystemModule

# Skill Categories
enum SkillCategory {
	SURVIVAL,
	TECHNOLOGY,
	COMBAT,
	SOCIAL
}

# Individual Skills
const SKILLS = {
	# SURVIVAL
	"ENVIRONMENTAL_ADAPTATION": {
		"category": SkillCategory.SURVIVAL,
		"display_name": "Environmental Adaptation",
		"description": "Resistance to harsh environments and weather conditions"
	},
	"LIFE_SUPPORT": {
		"category": SkillCategory.SURVIVAL,
		"display_name": "Life Support",
		"description": "Efficiency in managing oxygen, water, and vital resources"
	},
	"SCAVENGING": {
		"category": SkillCategory.SURVIVAL,
		"display_name": "Scavenging",
		"description": "Finding and extracting valuable resources from the wasteland"
	},
	
	# TECHNOLOGY
	"AUTOMATION_ENGINEERING": {
		"category": SkillCategory.TECHNOLOGY,
		"display_name": "Automation Engineering",
		"description": "Building and optimizing automated systems"
	},
	"ELECTRONICS": {
		"category": SkillCategory.TECHNOLOGY,
		"display_name": "Electronics",
		"description": "Crafting and repairing electronic components"
	},
	"RESEARCH": {
		"category": SkillCategory.TECHNOLOGY,
		"display_name": "Research",
		"description": "Unlocking new technologies and blueprints"
	},
	
	# COMBAT
	"WEAPONRY": {
		"category": SkillCategory.COMBAT,
		"display_name": "Weaponry",
		"description": "Proficiency with weapons and damage dealing"
	},
	"TACTICS": {
		"category": SkillCategory.COMBAT,
		"display_name": "Tactics",
		"description": "Strategic combat planning and critical hit chance"
	},
	"DEFENSE": {
		"category": SkillCategory.COMBAT,
		"display_name": "Defense",
		"description": "Armor effectiveness and damage reduction"
	},
	
	# SOCIAL
	"INFILTRATION": {
		"category": SkillCategory.SOCIAL,
		"display_name": "Infiltration",
		"description": "Stealth and bypassing security systems"
	},
	"LEADERSHIP": {
		"category": SkillCategory.SOCIAL,
		"display_name": "Leadership",
		"description": "Managing survivors and improving morale"
	},
	"INTELLIGENCE": {
		"category": SkillCategory.SOCIAL,
		"display_name": "Intelligence",
		"description": "Information gathering and quest rewards"
	}
}

# XP Requirements per Level (hard-coded as requested)
const XP_REQUIREMENTS = [
	0,      # Level 0 (starting point)
	200,    # Level 1
	500,    # Level 2
	940,    # Level 3
	1572,   # Level 4
	2464,   # Level 5
	3699,   # Level 6
	5379,   # Level 7
	7587,   # Level 8
	10417,  # Level 9
	13950,  # Level 10
	18242,  # Level 11
	23307,  # Level 12
	29101,  # Level 13
	35776,  # Level 14
	43310,  # Level 15
	51631,  # Level 16
	60608,  # Level 17
	70354,  # Level 18
	80755,  # Level 19
	91655   # Level 20
]

const MAX_LEVEL = 20

# XP Constants for different actions
const XP_VALUES = {
	# SURVIVAL - Environmental Adaptation
	"ENVIRONMENTAL_DAMAGE_TAKEN": 8,      # When taking environmental damage
	"STORM_SURVIVED": 25,                 # Surviving a storm event
	"PROTECTIVE_EQUIPMENT_USED": 5,       # Using protective gear
	
	# SURVIVAL - Life Support  
	"FOOD_CONSUMED": 10,                  # Eating food
	"WATER_CONSUMED": 10,                 # Drinking water
	"HEALTH_RESTORED": 5,                 # Per 10 HP healed
	"OXYGEN_MANAGED": 3,                  # Managing oxygen levels
	
	# SURVIVAL - Scavenging
	"RESOURCE_GATHERED": 5,               # Basic resource collection
	"RARE_RESOURCE_FOUND": 15,            # Finding rare resources
	"RESOURCE_NODE_DISCOVERED": 10,       # Discovering new nodes
	
	# TECHNOLOGY - Automation Engineering
	"CONVEYOR_BUILT": 20,                 # Building conveyor belts
	"MACHINE_CONNECTED": 15,              # Connecting machines
	"AUTOMATION_OUTPUT": 2,               # Per item produced by automation
	
	# TECHNOLOGY - Electronics
	"ELECTRONIC_CRAFTED": 12,             # Crafting electronic items
	"EQUIPMENT_REPAIRED": 15,             # Repairing equipment
	"DEVICE_USED": 5,                     # Using electronic devices
	
	# TECHNOLOGY - Research
	"BLUEPRINT_DISCOVERED": 30,           # Finding new blueprints
	"RECIPE_UNLOCKED": 20,                # Unlocking new recipes
	"RESEARCH_COMPLETED": 25              # Completing research
}

# Debug mode for XP gain messages
var debug_xp_messages: bool = false

# XP gain history for debugging
var xp_history: Array = []
const MAX_HISTORY_SIZE = 20

# Skill progress tracking
var skill_data: Dictionary = {}

# Placeholder for future perk system
var perk_data: Dictionary = {}
var available_perks: Dictionary = {}

# Signals
signal skill_xp_gained(skill: String, amount: int)
signal skill_level_up(skill: String, new_level: int)
signal skill_milestone_reached(category: SkillCategory, total_levels: int)

func _ready() -> void:
	initialize_skills()
	print("SkillSystem initialized")

func initialize_skills() -> void:
	for skill_id in SKILLS:
		skill_data[skill_id] = {
			"xp": 0,
			"level": 0,
			"total_xp": 0  # Track lifetime XP for statistics
		}
		# Initialize placeholder perk structures
		perk_data[skill_id] = []
		available_perks[skill_id] = []

# Core XP and Level Functions
func add_xp(skill: String, amount: int, source: String = "") -> void:
	if not skill in skill_data:
		push_error("Invalid skill: " + skill)
		return
	
	if amount <= 0:
		return
	
	var data = skill_data[skill]
	var old_level = data.level
	
	# Add XP
	data.xp += amount
	data.total_xp += amount
	
	# Add to XP history for debugging
	var history_entry = {
		"skill": skill,
		"skill_name": SKILLS[skill].display_name,
		"amount": amount,
		"source": source,
		"timestamp": Time.get_ticks_msec(),
		"new_total": data.xp + amount,
		"level_before": old_level
	}
	xp_history.push_front(history_entry)
	if xp_history.size() > MAX_HISTORY_SIZE:
		xp_history.pop_back()
	
	# Debug message if enabled
	if debug_xp_messages:
		var source_text = " from " + source if source != "" else ""
		print("[SKILL XP] +%d XP to %s%s (Total: %d)" % [amount, SKILLS[skill].display_name, source_text, data.xp + amount])
	
	# Check for level up
	while data.level < MAX_LEVEL and data.xp >= XP_REQUIREMENTS[data.level + 1]:
		data.level += 1
		print("LEVEL UP! %s reached level %d" % [SKILLS[skill].display_name, data.level])
		skill_level_up.emit(skill, data.level)
		
		# Check for category milestone
		check_category_milestone(SKILLS[skill].category)
	
	skill_xp_gained.emit(skill, amount)
	
	# Emit EventBus signal if available
	if has_node("/root/EventBus"):
		EventBus.call_deferred("emit_signal", "skill_xp_gained", skill, amount)
		if old_level != data.level:
			EventBus.call_deferred("emit_signal", "skill_level_up", skill, data.level)

func get_skill_level(skill: String) -> int:
	if not skill in skill_data:
		push_error("Invalid skill: " + skill)
		return 0
	return skill_data[skill].level

func get_skill_xp(skill: String) -> int:
	if not skill in skill_data:
		push_error("Invalid skill: " + skill)
		return 0
	return skill_data[skill].xp

func get_total_skill_xp(skill: String) -> int:
	if not skill in skill_data:
		push_error("Invalid skill: " + skill)
		return 0
	return skill_data[skill].total_xp

func get_xp_for_next_level(skill: String) -> int:
	if not skill in skill_data:
		push_error("Invalid skill: " + skill)
		return 0
	
	var level = skill_data[skill].level
	if level >= MAX_LEVEL:
		return 0  # Max level reached
	
	return XP_REQUIREMENTS[level + 1] - skill_data[skill].xp

func get_xp_progress_percent(skill: String) -> float:
	if not skill in skill_data:
		return 0.0
	
	var data = skill_data[skill]
	if data.level >= MAX_LEVEL:
		return 100.0
	
	var current_level_xp = XP_REQUIREMENTS[data.level]
	var next_level_xp = XP_REQUIREMENTS[data.level + 1]
	var progress = data.xp - current_level_xp
	var required = next_level_xp - current_level_xp
	
	return (float(progress) / float(required)) * 100.0

func check_category_milestone(category: SkillCategory) -> void:
	var total_levels = 0
	for skill_id in SKILLS:
		if SKILLS[skill_id].category == category:
			total_levels += skill_data[skill_id].level
	
	# Emit milestone signal every 5 total levels in a category
	if total_levels % 5 == 0 and total_levels > 0:
		skill_milestone_reached.emit(category, total_levels)

# Save/Load Functions
func get_save_data() -> Dictionary:
	return {
		"skill_data": skill_data.duplicate(true),
		"perk_data": perk_data.duplicate(true)
	}

func load_save_data(data: Dictionary) -> void:
	if "skill_data" in data:
		skill_data = data.skill_data.duplicate(true)
		# Ensure all skills exist (for save compatibility)
		for skill_id in SKILLS:
			if not skill_id in skill_data:
				skill_data[skill_id] = {
					"xp": 0,
					"level": 0,
					"total_xp": 0
				}
	
	if "perk_data" in data:
		perk_data = data.perk_data.duplicate(true)

# Utility Functions
func get_all_skills() -> Array:
	return SKILLS.keys()

func get_skills_by_category(category: SkillCategory) -> Array:
	var skills = []
	for skill_id in SKILLS:
		if SKILLS[skill_id].category == category:
			skills.append(skill_id)
	return skills

func get_category_name(category: SkillCategory) -> String:
	match category:
		SkillCategory.SURVIVAL:
			return "Survival"
		SkillCategory.TECHNOLOGY:
			return "Technology"
		SkillCategory.COMBAT:
			return "Combat"
		SkillCategory.SOCIAL:
			return "Social"
		_:
			return "Unknown"

func get_skill_info(skill: String) -> Dictionary:
	if not skill in SKILLS:
		return {}
	
	var info = SKILLS[skill].duplicate()
	info["current_level"] = skill_data[skill].level
	info["current_xp"] = skill_data[skill].xp
	info["total_xp"] = skill_data[skill].total_xp
	info["xp_for_next_level"] = get_xp_for_next_level(skill)
	info["progress_percent"] = get_xp_progress_percent(skill)
	return info

# Debug Functions
func debug_add_xp(skill: String, amount: int) -> void:
	print("[DEBUG] Adding %d XP to %s" % [amount, skill])
	add_xp(skill, amount)

func debug_set_level(skill: String, level: int) -> void:
	if not skill in skill_data:
		push_error("Invalid skill: " + skill)
		return
	
	level = clamp(level, 0, MAX_LEVEL)
	skill_data[skill].level = level
	skill_data[skill].xp = XP_REQUIREMENTS[level] if level > 0 else 0
	print("[DEBUG] Set %s to level %d" % [skill, level])

func debug_print_all_skills() -> void:
	print("\n=== SKILL SYSTEM DEBUG ===")
	for category in SkillCategory.values():
		print("\n%s Skills:" % get_category_name(category))
		for skill_id in get_skills_by_category(category):
			var data = skill_data[skill_id]
			print("  %s: Level %d (XP: %d/%d)" % [
				SKILLS[skill_id].display_name,
				data.level,
				data.xp,
				XP_REQUIREMENTS[min(data.level + 1, MAX_LEVEL)]
			])
	print("========================\n")

func debug_reset_skill(skill: String) -> void:
	if not skill in skill_data:
		push_error("Invalid skill: " + skill)
		return
	
	skill_data[skill] = {
		"xp": 0,
		"level": 0,
		"total_xp": 0
	}
	print("[DEBUG] Reset skill: " + skill)

func debug_max_all_skills() -> void:
	for skill_id in SKILLS:
		debug_set_level(skill_id, MAX_LEVEL)
	print("[DEBUG] All skills set to maximum level")

func debug_reset_all_skills() -> void:
	initialize_skills()
	print("[DEBUG] All skills reset to level 0")

func set_debug_xp_messages(enabled: bool) -> void:
	debug_xp_messages = enabled
	print("[DEBUG] XP messages " + ("enabled" if enabled else "disabled"))

func get_xp_history() -> Array:
	return xp_history

func clear_xp_history() -> void:
	xp_history.clear()
	print("[DEBUG] XP history cleared")

# Test methods for triggering XP gains
func test_environmental_damage() -> void:
	if GameManager.player_node:
		GameManager.player_node.modify_health(-10)
		print("[TEST] Triggered environmental damage")

# Save/Load testing methods
func test_save_skills() -> void:
	if has_node("/root/SaveManager"):
		SaveManager.save_game()
		print("[TEST] Skills saved to file")
	else:
		print("[TEST ERROR] SaveManager not found")

func test_load_skills() -> void:
	if has_node("/root/SaveManager"):
		SaveManager.load_game()
		print("[TEST] Skills loaded from file")
	else:
		print("[TEST ERROR] SaveManager not found")

func test_save_load_cycle() -> void:
	print("[TEST] Starting save/load cycle test")
	
	# Record current state
	var original_state = {}
	for skill_id in SKILLS:
		original_state[skill_id] = {
			"level": skill_data[skill_id].level,
			"xp": skill_data[skill_id].xp,
			"total_xp": skill_data[skill_id].total_xp
		}
	
	# Add some test XP
	add_xp("SCAVENGING", 100, "test_save_load")
	add_xp("ELECTRONICS", 50, "test_save_load")
	
	# Save the game
	test_save_skills()
	
	# Reset skills
	initialize_skills()
	print("[TEST] Skills reset - should be back to level 0")
	
	# Load the game
	test_load_skills()
	
	# Verify restoration
	var scavenging_restored = skill_data["SCAVENGING"].total_xp > original_state["SCAVENGING"].total_xp
	var electronics_restored = skill_data["ELECTRONICS"].total_xp > original_state["ELECTRONICS"].total_xp
	
	if scavenging_restored and electronics_restored:
		print("[TEST SUCCESS] Save/load cycle completed successfully!")
	else:
		print("[TEST FAILED] Save/load cycle failed to restore skills properly")

# Comprehensive testing suite
func run_comprehensive_tests() -> void:
	print("\n=== COMPREHENSIVE SKILL SYSTEM TESTS ===")
	
	# Test 1: XP Gain
	print("\n[TEST 1] XP Gain Test")
	var initial_xp = skill_data["SCAVENGING"].xp
	add_xp("SCAVENGING", 25, "comprehensive_test")
	var after_xp = skill_data["SCAVENGING"].xp
	if after_xp == initial_xp + 25:
		print("✅ XP gain working correctly")
	else:
		print("❌ XP gain failed: Expected %d, got %d" % [initial_xp + 25, after_xp])
	
	# Test 2: Level Up
	print("\n[TEST 2] Level Up Test")
	var initial_level = skill_data["LIFE_SUPPORT"].level
	var xp_needed = get_xp_for_next_level("LIFE_SUPPORT")
	add_xp("LIFE_SUPPORT", xp_needed, "level_up_test")
	var new_level = skill_data["LIFE_SUPPORT"].level
	if new_level == initial_level + 1:
		print("✅ Level up working correctly")
	else:
		print("❌ Level up failed: Expected level %d, got %d" % [initial_level + 1, new_level])
	
	# Test 3: All Skills Accessible
	print("\n[TEST 3] All Skills Accessible Test")
	var all_accessible = true
	for skill_id in SKILLS:
		if not skill_id in skill_data:
			print("❌ Skill %s not accessible" % skill_id)
			all_accessible = false
	if all_accessible:
		print("✅ All 12 skills accessible")
	
	# Test 4: XP History
	print("\n[TEST 4] XP History Test")
	var history_size_before = xp_history.size()
	add_xp("RESEARCH", 10, "history_test")
	var history_size_after = xp_history.size()
	if history_size_after > history_size_before:
		print("✅ XP history tracking working")
	else:
		print("❌ XP history not tracking properly")
	
	# Test 5: Save/Load
	print("\n[TEST 5] Save/Load Test")
	test_save_load_cycle()
	
	print("\n=== TESTS COMPLETED ===\n")