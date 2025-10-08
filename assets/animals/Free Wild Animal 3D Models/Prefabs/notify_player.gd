extends AnimationPlayer

var notifier : String

func notifies(anim :String, value : String = "") -> void:
	notifier = value
	print(value)
