# InventorySystem.gd Code Review

## Potential Bugs & Edge Cases
- **Slot-targeted drops remove the wrong stack:** `drop_item_from_slot()` resolves the drop quantity from the chosen slot, but then forwards to `drop_item()`, which calls `remove_item()` and iterates from slot index `0`. If multiple stacks of the same `item_id` exist, the removal will occur from the earliest stack instead of the requested slot, leaving the targeted slot untouched. This makes the drop action unpredictable for duplicate stacks.
- **Slot initialization loop relies on implicit integer iteration:** `_ready()` uses `for i in BASE_SLOTS:`. GDScript does not implicitly iterate integers prior to 4.3, so this will raise a runtime error unless the project runs on the latest preview builds. Use `for i in range(BASE_SLOTS):` for compatibility.
- **Save data may truncate expanded inventories:** `load_save_data()` only iterates over the current `inventory_slots` length. If a save file contains more slots (e.g., because of `bonus_inventory_slots`), the extra slots are ignored unless `update_inventory_size()` is invoked beforehand. This can silently delete saved items.

## Unclear or Fragile Logic
- **Bonus slot lookup is brittle:** `get_max_slots()` reaches into `GameManager.player_node` for `bonus_inventory_slots`. If the player node is freed or lacks that property, the system silently falls back to the base size. A dedicated accessor on the player/autoload would make the contract clearer.
- **`max_stack` resets to `1` on every clear:** `InventorySlot.clear()` always resets `max_stack` to `1`. This relies on higher-level code to re-fetch stack limits before reusing the slot. Documenting this expectation or caching max stacks per item would avoid accidental under-stacking.

## Bloat & Debug Artefacts
- `WOOD_SCRAP_STACK_SIZE` is unused and can be removed.
- Frequent `print()` calls in `add_item()`, `drop_item()`, and `update_inventory_size()` spam the output during normal play. Consider routing them through a debug flag or logging wrapper.

## Suggestions for Improvement
- Pass the target slot index (or direct `InventorySlot`) into `remove_item()` or create a dedicated `remove_from_slot()` helper to ensure drops modify the intended stack.
- Replace the slot initialization loop with `inventory_slots.resize(BASE_SLOTS)` or a `for i in range(BASE_SLOTS)` loop for clarity.
- Invoke `update_inventory_size()` before applying save data, and store the saved slot count to keep expanded inventories consistent across sessions.
- Wrap the `GameManager` access behind a method such as `GameManager.get_bonus_inventory_slots()` to decouple the system from node internals and simplify testing.
- Gate verbose prints behind a `debug_inventory` flag or use `print_verbose()` so production builds stay quiet.

