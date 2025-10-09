extends Area3D
class_name TurretProjectile

@export var speed: float = 50.0
@export var lifetime: float = 3.0  # How many seconds before the projectile disappears
@export var damage: float = 15.0  # Damage dealt to targets

func _ready():
	# Connect body_entered signal
	body_entered.connect(_on_body_entered)

	# Disappear after 'lifetime' seconds to clean up the scene
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	# Move the projectile forward in its local -Z direction (forward)
	global_position += -global_transform.basis.z * speed * delta

func _on_body_entered(body: Node3D):
	# Deal damage to animals
	if body.is_in_group("animals"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
			print("Turret projectile hit %s for %d damage" % [body.name, damage])

	# Disappear on impact
	queue_free()
