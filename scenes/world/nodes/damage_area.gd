# DamageArea3D.gd
extends Area3D

@export var damage_amount: int = 10
@export var deals_damage_on_enter: bool = true
@export var deals_damage_over_time: bool = true

var bodies_in_area: Array = []

func _on_body_entered(body: Node3D):
	if body.has_method("take_damage"):
		bodies_in_area.append(body)

		if deals_damage_on_enter:
			body.take_damage(damage_amount)

		if deals_damage_over_time and $Timer.is_stopped():
			$Timer.start()

func _on_body_exited(body: Node3D):
	if body.has_method("take_damage"):
		bodies_in_area.erase(body)

		if bodies_in_area.is_empty():
			$Timer.stop()

func _on_timer_timeout():
	for body in bodies_in_area:
		body.take_damage(damage_amount)
