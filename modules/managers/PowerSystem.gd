extends Node

signal power_state_changed(has_power: bool)
signal generator_added(generator: Node2D)
signal generator_removed(generator: Node2D)
signal powered_device_added(device: Node2D)
signal powered_device_removed(device: Node2D)

const POWER_RANGE: float = 150.0  # Range in pixels for power transmission
const POWER_CHECK_INTERVAL: float = 0.5  # Check power connections every 0.5 seconds

var generators: Array[Node2D] = []
var powered_devices: Array[Node2D] = []
var power_connections: Dictionary = {}  # device -> generator mapping
var check_timer: Timer

func _ready():
	print("PowerSystem: Initializing...")
	add_to_group("power_system")
	
	# Setup timer for periodic power checks
	check_timer = Timer.new()
	check_timer.wait_time = POWER_CHECK_INTERVAL
	check_timer.timeout.connect(_check_power_connections)
	add_child(check_timer)
	check_timer.start()

func register_generator(generator: Node2D):
	if generator in generators:
		return
	
	generators.append(generator)
	print("PowerSystem: Registered generator at ", generator.global_position)
	generator_added.emit(generator)
	
	# Connect to generator signals if available
	if generator.has_signal("generator_cranked"):
		generator.generator_cranked.connect(func(): _on_generator_state_changed(generator))
	if generator.has_signal("generator_stopped"):
		generator.generator_stopped.connect(func(): _on_generator_state_changed(generator))
	
	# Immediate power check
	_check_power_connections()

func unregister_generator(generator: Node2D):
	if generator not in generators:
		return
	
	generators.erase(generator)
	print("PowerSystem: Unregistered generator")
	generator_removed.emit(generator)
	
	# Remove any power connections from this generator
	var devices_to_update = []
	for device in power_connections:
		if power_connections[device] == generator:
			devices_to_update.append(device)
	
	for device in devices_to_update:
		power_connections.erase(device)
		if device.has_method("set_powered"):
			device.set_powered(false)
	
	_check_power_connections()

func register_powered_device(device: Node2D):
	if device in powered_devices:
		return
	
	powered_devices.append(device)
	print("PowerSystem: Registered powered device at ", device.global_position)
	powered_device_added.emit(device)
	
	# Immediate power check for this device
	_check_device_power(device)

func unregister_powered_device(device: Node2D):
	if device not in powered_devices:
		return
	
	powered_devices.erase(device)
	power_connections.erase(device)
	print("PowerSystem: Unregistered powered device")
	powered_device_removed.emit(device)

func _check_power_connections():
	# Check each device for power availability
	for device in powered_devices:
		if is_instance_valid(device):
			_check_device_power(device)

func _check_device_power(device: Node2D):
	if not is_instance_valid(device):
		return
	
	var nearest_generator = null
	var min_distance = POWER_RANGE + 1.0
	
	# Find nearest active generator within range
	for generator in generators:
		if not is_instance_valid(generator):
			continue
		
		# Check if generator is running
		if generator.has_method("is_generator_running"):
			if not generator.is_generator_running():
				continue
		elif "is_running" in generator:
			if not generator.is_running:
				continue
		else:
			# Assume it's running if we can't check
			pass
		
		var distance = device.global_position.distance_to(generator.global_position)
		if distance <= POWER_RANGE and distance < min_distance:
			nearest_generator = generator
			min_distance = distance
	
	# Update power connection
	var was_powered = device in power_connections
	var is_powered = nearest_generator != null
	
	if is_powered:
		power_connections[device] = nearest_generator
	else:
		power_connections.erase(device)
	
	# Notify device of power state change
	if device.has_method("set_powered"):
		device.set_powered(is_powered)
	
	# Emit signal if power state changed
	if was_powered != is_powered:
		print("PowerSystem: Device power state changed - ", "POWERED" if is_powered else "UNPOWERED")
		power_state_changed.emit(is_powered)

func _on_generator_state_changed(_generator: Node2D):
	print("PowerSystem: Generator state changed, rechecking connections...")
	_check_power_connections()

func is_device_powered(device: Node2D) -> bool:
	return device in power_connections

func get_power_source(device: Node2D) -> Node2D:
	if device in power_connections:
		return power_connections[device]
	return null

func get_power_range() -> float:
	return POWER_RANGE

func get_all_generators() -> Array:
	return generators.duplicate()

func get_all_powered_devices() -> Array:
	return powered_devices.duplicate()

func get_running_generators() -> Array:
	var running = []
	for generator in generators:
		if not is_instance_valid(generator):
			continue
		
		var is_running = false
		if generator.has_method("is_generator_running"):
			is_running = generator.is_generator_running()
		elif "is_running" in generator:
			is_running = generator.is_running
		
		if is_running:
			running.append(generator)
	
	return running
