extends Resource
class_name ResourceDrop

## Configuration for resource drops from minable nodes

@export var item_id: String = ""
@export var min_amount: int = 1
@export var max_amount: int = 3
@export_range(0.0, 1.0) var drop_chance: float = 1.0
