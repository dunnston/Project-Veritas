# PlayerCombat.gd Review

## Potential Bugs & Edge Cases
- `_process` decrements `attack_timer`, but the script never enables processing. In Godot, Nodes do not process by default; without calling `set_process(true)` (or inheriting from a class that processes automatically), cooldowns never recover and the player becomes unable to attack after the first swing. 【F:scripts/player/PlayerCombat.gd†L34-L39】
- `event.global_position` is accessed for every `attack` press. `InputEventAction` (triggered by keyboard bindings) does not expose `global_position`, so pressing an attack key will raise an error. Use the player's mouse position or guard with `event is InputEventMouse` before reading that property. 【F:scripts/player/PlayerCombat.gd†L47-L54】
- `weapon.attack_speed` is used as a divisor for cooldown and as a multiplier for projectile speed without validation. Weapons with a zero or very small attack speed will crash with division-by-zero or produce absurd projectile behaviour; clamp or validate these stats. 【F:scripts/player/PlayerCombat.gd†L184-L185】【F:scripts/player/PlayerCombat.gd†L148】
- `create_hit_effect` and `show_reload_message` instantiate `Label` nodes directly under the current scene. If the active scene is not a `CanvasItem`, the label may fail to render or inherit unexpected transforms; consider adding them to a dedicated `CanvasLayer`/UI root. 【F:scripts/player/PlayerCombat.gd†L240-L377】

## Unclear / Brittle Logic
- `get_current_weapon_data` mixes pixel distances and arbitrary range multipliers (`base_punch_range * weapon.attack_range`, `weapon.attack_range * 50`). Document how `attack_range` is expected to be normalized, or convert to a single unit at the weapon level to avoid magic numbers. 【F:scripts/player/PlayerCombat.gd†L186-L191】
- `perform_ranged_attack` ignores its `_target_pos` parameter and always shoots towards the mouse. If the intent is to allow aim assist or controller input, the unused argument is misleading. 【F:scripts/player/PlayerCombat.gd†L115-L154】
- `check_melee_hit` collects enemies by scanning an entire group every swing and relies solely on direction/arc math. The unused `space_state` and `attack_center` hint that a Physics query was intended; either use an `intersect_shape` for accuracy or remove the dead code. 【F:scripts/player/PlayerCombat.gd†L205-L211】

## Excess Debug / Bloat
- Numerous `print` statements (e.g., per attack, UI blocking checks) will spam the console and hurt performance on release builds. Replace with a logging utility that can be toggled or remove non-essential logs. 【F:scripts/player/PlayerCombat.gd†L32-L138】【F:scripts/player/PlayerCombat.gd†L255-L359】
- Unused locals such as `space_state` and `attack_center` should be removed to reduce confusion and satisfy linters. 【F:scripts/player/PlayerCombat.gd†L205-L211】

## Suggestions for Improvement
- Enable/disable `_process` based on combat state (`set_process(can_attack == false)`) to avoid per-frame work when idle and to guarantee cooldown handling. 【F:scripts/player/PlayerCombat.gd†L34-L39】
- Extract UI pop-up creation into reusable helper methods (e.g., a dedicated `FloatingTextSpawner`) to centralize styling and reuse between hit markers and reload prompts. 【F:scripts/player/PlayerCombat.gd†L240-L377】
- Cache references to frequently queried groups (`enemies`, `weapon_ui`) or leverage area nodes/physics overlap checks to reduce per-frame allocations and tree walks. 【F:scripts/player/PlayerCombat.gd†L213-L359】
- Replace hard-coded timers with animation notifies or weapon data hooks so that attack cadence follows the animation/state machine rather than fixed delays, improving maintainability as assets change. 【F:scripts/player/PlayerCombat.gd†L95-L112】

