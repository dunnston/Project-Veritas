extends Resource
class_name NodeSpawnConfig

## Configuration for spawning resource nodes

@export var node_scene: PackedScene
@export var spawn_weight: float = 1.0
@export var can_respawn: bool = true
@export var respawn_time: float = 0.0  # 0 = use node's default
@export var random_rotation: bool = true
@export_range(0.0, 0.5) var scale_variation: float = 0.1
