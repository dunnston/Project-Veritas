## AnimalDrop.gd
## Resource defining a loot drop from an animal
## Includes item ID, quantity range, and drop chance
class_name AnimalDrop
extends Resource

## Item ID to drop (from items data)
@export var item_id: String = ""

## Minimum quantity to drop
@export var min_amount: int = 1

## Maximum quantity to drop
@export var max_amount: int = 3

## Chance to drop (0.0 to 1.0)
@export_range(0.0, 1.0) var drop_chance: float = 1.0
