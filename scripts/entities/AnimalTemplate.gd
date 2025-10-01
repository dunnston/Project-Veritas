## AnimalTemplate.gd
## Resource defining an animal type
## Contains all stats, behavior, appearance, and loot data
class_name AnimalTemplate
extends Resource

## Display name
@export var animal_name: String = "Animal"

## Scene to instantiate (should have Animal.gd script)
@export var scene: PackedScene

## Optional mesh override
@export var mesh: Mesh

## Behavior type
@export var behavior_type: Animal.BehaviorType = Animal.BehaviorType.NEUTRAL

## Health
@export var max_health: float = 100.0

## Movement speeds
@export var move_speed: float = 5.0
@export var run_speed: float = 8.0

## AI ranges
@export var aggro_range: float = 10.0
@export var flee_range: float = 15.0
@export var attack_range: float = 2.0

## Combat stats
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.5

## Loot drops
@export var loot_drops: Array[AnimalDrop] = []
