class_name InventorySlot

## Inventory Slot Data Structure
##
## Represents a single slot in an inventory system with item stacking support.
## Part of the Modular Inventory System.

var item_id: String = ""
var quantity: int = 0
var max_stack: int = 1

func _init(id: String = "", qty: int = 0, stack_size: int = 1):
	item_id = id
	quantity = qty
	max_stack = stack_size

## Check if slot is empty
func is_empty() -> bool:
	return item_id.is_empty() or quantity <= 0

## Check if we can add items to this slot
func can_add_item(id: String, qty: int) -> bool:
	if is_empty():
		return true
	return item_id == id and (quantity + qty) <= max_stack

## Add items to this slot, returns amount actually added
func add_items(qty: int) -> int:
	var added = min(qty, max_stack - quantity)
	quantity += added
	return added

## Remove items from this slot, returns amount actually removed
func remove_items(qty: int) -> int:
	var removed = min(qty, quantity)
	quantity -= removed
	if quantity <= 0:
		clear()
	return removed

## Clear the slot
func clear():
	item_id = ""
	quantity = 0
	max_stack = 1

## Get slot data as dictionary for serialization
func to_dict() -> Dictionary:
	if is_empty():
		return {}

	return {
		"item_id": item_id,
		"quantity": quantity,
		"max_stack": max_stack
	}

## Load slot data from dictionary
func from_dict(data: Dictionary):
	if data.is_empty():
		clear()
	else:
		item_id = data.get("item_id", "")
		quantity = data.get("quantity", 0)
		max_stack = data.get("max_stack", 1)

## Get remaining space in this slot for the same item
func get_remaining_space() -> int:
	if is_empty():
		return max_stack
	return max_stack - quantity

## Check if slot is full
func is_full() -> bool:
	return quantity >= max_stack

## Get slot info string for debugging
func get_debug_string() -> String:
	if is_empty():
		return "[Empty Slot]"
	return "%s x%d/%d" % [item_id, quantity, max_stack]
