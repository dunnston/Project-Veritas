# Combat System Documentation

## Table of Contents
1. [Player Guide](#player-guide) - **Start here for gameplay mechanics**
2. [System Overview](#system-overview)
3. [Architecture](#architecture)
4. [Setup Instructions](#setup-instructions)
5. [API Reference](#api-reference)
6. [Combat Mechanics](#combat-mechanics)
7. [Examples and Use Cases](#examples-and-use-cases)
8. [Troubleshooting](#troubleshooting)
9. [Future Improvements](#future-improvements)

---

## Player Guide

### How Combat Works

In Neon Wasteland 3D, you can engage in combat using melee weapons (knives, axes, swords) or ranged weapons (guns, bows). Combat is third-person, meaning you attack where your camera is looking.

### Controls

| Action | Key/Button | Description |
|--------|-----------|-------------|
| **Attack** | **Left Mouse Button** | Swing melee weapon or fire ranged weapon |
| **Switch Weapon** | **Q** | Cycle through: Primary → Secondary → Fists |
| **Reload** | **R** | Reload your ranged weapon from inventory ammo |
| **Open Inventory** | **Tab** | Equip/unequip weapons and manage ammo |

### Combat Basics

#### Attacking
- **Melee**: Click to swing your weapon. You'll hit anything in front of you within range (about 60° cone)
- **Ranged**: Click to fire a projectile. Aim where you're looking - the bullet/arrow flies toward your crosshair
- **Fists**: No weapon equipped? Fight with your bare hands for basic damage

#### Weapon Switching
Press **Q** to cycle through your equipped weapons:
1. **Primary Weapon** (main weapon slot)
2. **Secondary Weapon** (backup weapon slot)
3. **Fists** (unarmed combat)
4. Back to Primary...

#### Damage Numbers
When you hit an enemy, you'll see colored numbers:
- **Orange numbers** = Normal hit
- **Red numbers (larger)** = Critical hit! Extra damage

#### Weapon Durability
Weapons wear down as you use them:
- Each attack reduces durability
- At 0 durability, the weapon breaks and becomes unusable
- Check weapon condition in inventory (hover over weapon)
- Repair weapons at workbenches (future feature)

### Ranged Weapons

#### Ammunition System
Guns and bows require ammo:
- Each weapon type uses specific ammo (bullets for guns, arrows for bows)
- Ammo is loaded into a **magazine** (e.g., assault rifles hold 30 bullets)
- When magazine is empty, you must reload

#### Reloading
1. Press **R** to reload
2. Ammo is pulled from your inventory automatically
3. If you have no ammo in inventory, you'll see "NO AMMO TO RELOAD!"
4. Watch the ammo counter on your HUD (e.g., "30/30" = full magazine)

#### Ammo Types
Different ammo types provide bonuses:
- **Scrap Bullets**: Basic ammo for most guns
- **Fire Bullets**: Causes burning damage over time (future)
- **Wood Arrows**: Basic arrows for bows
- **Steel Arrows**: Higher damage arrows

### Melee Weapons

#### Attack Range
Melee weapons have a short reach:
- **Fists**: ~1.5 meters
- **Knives**: ~2 meters
- **Swords/Axes**: ~2.5 meters

#### Attack Arc
You don't need to aim precisely - melee attacks hit anything in a 120° cone in front of you:
- Aim your camera at the enemy
- Click to attack
- If enemy is within range and in front of you, you'll hit them

#### Critical Hits
Some melee weapons have a chance to deal critical damage:
- Higher tier weapons have better crit chance
- Critical hits deal 50% extra damage
- Watch for RED damage numbers!

### Equipping Weapons

#### From Inventory (Tab Menu)
1. Press **Tab** to open inventory
2. Find a weapon in your inventory
3. **Ctrl + Left Click** on the weapon
4. It equips to your Primary or Secondary slot (whichever is free)
5. Press **Tab** again to close inventory

#### Weapon Slots
- **Primary Weapon**: Your main weapon (slot 1)
- **Secondary Weapon**: Your backup weapon (slot 2)
- **Tool Slot**: For gathering tools like axes/pickaxes (separate from combat)

#### Unequipping
1. Open inventory (Tab)
2. Click on an equipped weapon in your equipment panel
3. It returns to your inventory

### Combat Tips

**For Melee:**
- Keep enemies in front of your camera
- Don't stand directly on top of enemies - back up slightly for better hits
- Watch your weapon durability - switch weapons before one breaks
- Critical hits are random - keep attacking for more chances

**For Ranged:**
- Manage your ammo - don't waste shots
- Reload during safe moments, not mid-combat
- Keep a melee weapon as backup when ammo runs low
- Projectiles take time to travel - lead moving targets

**General:**
- Press Q to switch weapons quickly without opening inventory
- Higher tier weapons = more damage and durability
- Animals drop resources when killed - combat is profitable!
- Some enemies are aggressive (attack on sight) while others are neutral (only fight back)

### Known Limitations

**Current Combat Quirks:**
- Melee attacks use camera direction only - you can hit enemies slightly to your side
- Attack arc is 120° (generous cone) - being tuned for more realism
- You cannot attack while inventory/menus are open (this is intentional)
- Ranged weapons fire from chest height, not from the weapon model

These will be refined in future updates!

---

## System Overview

The Combat System provides a complete framework for player combat in Neon Wasteland 3D, supporting both melee and ranged weapons with damage calculation, ammunition management, weapon switching, and visual feedback.

### Key Features

- **Dual Combat Modes**: Melee (fists, knives, swords) and ranged (guns, bows) weapons
- **Magazine System**: Realistic ammunition management with reload mechanics
- **Weapon Switching**: Quick-swap between primary, secondary, and fists
- **Camera-based Targeting**: Attacks hit what the player is looking at
- **Damage Feedback**: Floating damage numbers with critical hit display
- **Durability System**: Weapons degrade with use and can break
- **Ammo Types**: Multiple ammunition types with different damage modifiers
- **Weapon Stats**: Customizable stats including damage, speed, range, crit chance

### Core Components

- **PlayerCombat.gd** - Player-side combat handler
- **CombatSystem.gd** - Global damage calculation and combat management
- **Projectile.gd** - Ranged weapon projectile physics
- **Weapon.gd** - Weapon class with stats and durability
- **WeaponManager.gd** - Weapon slot and switching management
- **AmmoManager.gd** - Ammunition type management
- **ProjectileSystem.gd** - Projectile spawning and pooling

---

## Architecture

### Component Relationships

```
Player (CharacterBody3D)
├── PlayerCombat (Node)
│   ├── Detects input (attack, reload, switch)
│   ├── Performs melee hit detection
│   ├── Spawns projectiles via ProjectileSystem
│   └── Creates damage numbers
│
└── Depends on:
    ├── CombatSystem (Autoload) - Damage dealing
    ├── WeaponManager (Autoload) - Weapon state
    ├── ProjectileSystem (Autoload) - Projectile creation
    └── InventorySystem (Autoload) - Ammo consumption
```

### Data Flow

**Melee Attack Flow:**
```
1. Player presses attack input
2. PlayerCombat checks if attack is allowed
3. Get weapon data from WeaponManager
4. Check for enemies in attack arc using camera direction
5. CombatSystem.deal_damage() for each hit
6. Create damage numbers at hit position
7. Reduce weapon durability
8. Start cooldown timer
```

**Ranged Attack Flow:**
```
1. Player presses attack input
2. PlayerCombat checks ammo availability
3. Get weapon data from WeaponManager
4. Raycast from camera to determine target direction
5. ProjectileSystem.create_projectile()
6. Projectile travels and detects collision
7. On hit: CombatSystem.deal_damage()
8. Consume ammo and reduce durability
9. Start cooldown timer
```

---

## Setup Instructions

### 1. Add PlayerCombat to Player

```gdscript
# In your Player scene (CharacterBody3D)
# Add PlayerCombat as a child node

# Player.tscn structure:
Player (CharacterBody3D)
├── CharacterModel (Node3D)
├── CameraPivot (Node3D)
│   └── Camera3D
├── CollisionShape3D
└── PlayerCombat (Node)  # <-- Add this
```

Attach the script: `res://scripts/player/PlayerCombat.gd`

### 2. Configure PlayerCombat Properties

In the Inspector for PlayerCombat node:
- **Base Punch Damage**: 5 (unarmed damage)
- **Base Punch Range**: 50.0 (in units)
- **Base Attack Cooldown**: 0.5 (seconds)
- **Attack Arc**: 90.0 (degrees for melee hit detection)

### 3. Set Up Input Actions

In Project Settings → Input Map, ensure these actions exist:
- `attack` - Left Mouse Button
- `switch_weapon` - Q key
- `reload` - R key

### 4. Configure Autoload Singletons

Ensure these are in Project Settings → Autoload:
- **CombatSystem**: `res://scripts/systems/CombatSystem.gd`
- **WeaponManager**: `res://scripts/managers/WeaponManager.gd`
- **AmmoManager**: `res://scripts/managers/AmmoManager.gd`
- **ProjectileSystem**: `res://scripts/systems/ProjectileSystem.gd`
- **InventorySystem**: `res://scripts/systems/inventory_system/InventorySystem.gd`

### 5. Create Weapon Data

Create `res://data/weapons.json`:

```json
{
  "weapons": {
    "RUSTY_KNIFE": {
      "name": "Rusty Knife",
      "description": "A worn blade, barely sharp.",
      "type": "MELEE",
      "tier": 1,
      "damage": 15,
      "attack_speed": 1.2,
      "range": 1.5,
      "durability": 50,
      "stats": {
        "critical_chance": 0.1
      },
      "icon": "knife_rusty"
    },
    "SCRAP_PISTOL": {
      "name": "Scrap Pistol",
      "description": "A makeshift firearm.",
      "type": "RANGED",
      "tier": 1,
      "damage": 20,
      "attack_speed": 1.5,
      "range": 30.0,
      "durability": 100,
      "magazine_size": 10,
      "reload_time": 2.0,
      "compatible_ammo_types": ["BULLET"],
      "stats": {
        "accuracy": 0.85,
        "critical_chance": 0.05
      },
      "icon": "pistol_scrap"
    }
  }
}
```

---

## API Reference

### PlayerCombat

#### Methods

##### `perform_melee_attack() -> void`
Executes a melee attack with the currently equipped weapon or fists.
- Checks for enemies within attack arc
- Applies damage and knockback
- Creates damage numbers
- Reduces weapon durability

##### `perform_ranged_attack(target_pos: Vector3) -> void`
Fires a projectile from a ranged weapon.
- **Parameters**: `target_pos` - Not used (calculated from camera)
- Checks ammunition availability
- Spawns projectile via ProjectileSystem
- Consumes ammo and durability

##### `reload_weapon() -> void`
Reloads the active ranged weapon from inventory.
- Checks if weapon needs reload
- Attempts to load from inventory
- Shows reload feedback messages
- Waits for reload_time before completion

##### `cycle_weapons() -> void`
Cycles through equipped weapons: Primary → Secondary → Fists → Primary...
- Skips empty slots
- Emits weapon_switched signal
- Provides visual feedback

##### `get_current_weapon_data(calculate_crit: bool = false) -> Dictionary`
Returns current weapon stats as a dictionary.
- **Parameters**: `calculate_crit` - Whether to roll for critical hit
- **Returns**: Dictionary with keys:
  - `weapon`: Weapon object or null
  - `name`: String
  - `damage`: int
  - `range`: float
  - `cooldown`: float
  - `knockback`: float
  - `is_critical`: bool (if calculate_crit = true and crit rolled)

##### `create_damage_number(pos: Vector3, damage: int, is_critical: bool = false) -> void`
Creates a floating damage number at the specified position.
- **Parameters**:
  - `pos`: World position to spawn number
  - `damage`: Amount to display
  - `is_critical`: Use red/large for crits

##### `can_perform_attack() -> bool`
Checks if player can currently attack.
- **Returns**: true if cooldown finished and not currently attacking

##### `get_attack_cooldown_progress() -> float`
Gets current attack cooldown progress.
- **Returns**: 0.0 to 1.0 (1.0 = ready to attack)

#### Signals

- `attack_started()` - Emitted when attack animation begins
- `attack_finished()` - Emitted when attack completes
- `hit_enemy(enemy: Node)` - Emitted when enemy is hit
- `weapon_switched()` - Emitted when player switches weapons

### CombatSystem

#### Methods

##### `deal_damage(attacker: Node, target: Node, damage: int, damage_type: String = "physical") -> void`
Applies damage to a target entity.
- **Parameters**:
  - `attacker`: Node dealing damage
  - `target`: Node receiving damage
  - `damage`: Amount of damage
  - `damage_type`: "physical", "melee", "ranged", etc.
- Checks for friendly fire
- Calls target.take_damage()
- Logs combat event
- Emits damage_dealt signal

##### `apply_knockback(source: Node, target: Node, force: float) -> void`
Applies knockback force to target away from source.
- **Parameters**:
  - `source`: Origin of knockback
  - `target`: Entity to knock back
  - `force`: Magnitude of knockback

##### `calculate_melee_damage(attacker: Node) -> int`
Calculates base melee damage for an attacker.
- **Parameters**: `attacker` - Node to calculate damage for
- **Returns**: Base damage with modifiers applied

##### `is_friendly_fire(attacker: Node, target: Node) -> bool`
Checks if damage would be friendly fire.
- **Returns**: true if same team attacking same team

#### Signals

- `damage_dealt(attacker: Node, target: Node, amount: int)` - After damage applied
- `enemy_killed(enemy: Node, killer: Node)` - When enemy dies

### Weapon Class

#### Properties

- `id: String` - Unique weapon identifier
- `name: String` - Display name
- `type: String` - "MELEE" or "RANGED"
- `damage: int` - Base damage
- `attack_speed: float` - Attacks per second
- `attack_range: float` - Range in meters
- `durability: int` - Max durability
- `current_durability: int` - Current durability
- `magazine_size: int` - Ammo capacity (ranged only)
- `current_ammo: int` - Current loaded ammo (ranged only)
- `reload_time: float` - Reload duration in seconds
- `compatible_ammo_types: Array[String]` - Allowed ammo types
- `stats: Dictionary` - Custom stats (crit_chance, accuracy, etc.)

#### Methods

##### `is_melee() -> bool`
Returns true if weapon type is MELEE.

##### `is_ranged() -> bool`
Returns true if weapon type is RANGED.

##### `can_attack() -> bool`
Checks if weapon can currently attack.
- Returns false if durability is 0
- Returns false if ranged weapon has no ammo

##### `use_weapon() -> bool`
Consumes durability and ammo (if ranged).
- Returns false if can't attack
- Reduces current_ammo by 1 (ranged)
- Reduces current_durability by 1

##### `get_effective_damage() -> int`
Calculates damage with all modifiers.
- Applies durability degradation
- Applies ammo damage modifier (ranged)

##### `reload_from_inventory() -> bool`
Reloads weapon from InventorySystem.
- Checks for selected_ammo_id
- Consumes ammo from inventory
- Returns true if successful

##### `needs_reload() -> bool`
Returns true if ranged weapon has less than full magazine.

### WeaponManager

#### Methods

##### `create_weapon(weapon_id: String) -> Weapon`
Creates a weapon instance from weapons.json.
- **Parameters**: `weapon_id` - ID from weapons.json
- **Returns**: Weapon object or null

##### `equip_weapon(weapon: Weapon, slot: String = "") -> bool`
Equips weapon to specified slot.
- **Parameters**:
  - `weapon`: Weapon to equip
  - `slot`: "PRIMARY_WEAPON" or "SECONDARY_WEAPON"
- Unequips existing weapon in slot
- Auto-equips compatible ammo if ranged

##### `unequip_weapon(slot: String) -> Weapon`
Unequips weapon from slot and returns it to inventory.

##### `get_active_weapon() -> Weapon`
Returns currently active weapon or null.

##### `switch_weapon() -> bool`
Switches between primary and secondary slots.

#### Signals

- `weapon_equipped(weapon: Weapon, slot: String)`
- `weapon_unequipped(slot: String)`
- `weapon_switched(active_weapon: Weapon)`
- `weapon_reloaded(weapon: Weapon)`

---

## Combat Mechanics

### Melee Combat

**Hit Detection:**
- Uses camera direction for aiming (where player is looking)
- Checks all enemies/animals within attack range
- Validates enemy is within 120° attack arc from camera direction
- Hits all valid targets in arc (multi-target capable)

**Damage Calculation:**
```
Effective Damage = Base Damage × Durability Ratio × Player Modifiers
Critical Damage = Effective Damage × 1.5

Where:
  Durability Ratio = current_durability / max_durability
  Player Modifiers = from player.get_damage_modifier()
```

**Attack Cooldown:**
```
Cooldown = Base Cooldown / Weapon Attack Speed

Example:
  Base: 0.5s, Weapon Speed: 1.2
  Actual Cooldown: 0.5 / 1.2 = 0.417s
```

### Ranged Combat

**Projectile Spawning:**
- Spawns at player chest height (position + Vector3(0, 1.5, 0))
- Direction calculated from camera raycast
- Speed and range from weapon stats
- Gravity disabled (straight trajectory)

**Hit Detection:**
- Uses RigidBody3D physics
- Collision layers: Layer 6 (Projectiles)
- Collision mask: 1 (World) + 2 (Player) + 16 (Enemies)
- Auto-destroys on impact or max range

**Ammunition:**
- Magazine system: Must reload when empty
- Reload consumes ammo from inventory
- Reload time varies per weapon (1.0s - 3.0s)
- Different ammo types provide damage modifiers

### Critical Hits

**Calculation:**
```gdscript
var crit_roll = randf()  # 0.0 to 1.0
if crit_roll < weapon.get_stat_value("critical_chance"):
    damage = int(damage * 1.5)
    is_critical = true
```

**Visual Feedback:**
- Normal hits: Orange numbers, 24 font size
- Critical hits: Red numbers, 32 font size
- Numbers float upward and fade out

### Durability System

**Degradation:**
- Each attack reduces durability by 1
- Damage scales with durability: `damage * (current / max)`
- At 0 durability: weapon breaks, can't attack

**Example:**
```
Knife: 50/50 durability = 100% damage (15 dmg)
Knife: 25/50 durability = 50% damage (7.5 dmg)
Knife: 0/50 durability = Can't attack
```

### Weapon Switching

**Cycle Order:**
1. Primary Weapon (if equipped)
2. Secondary Weapon (if equipped)
3. Fists (always available)
4. Back to Primary

**Behavior:**
- Skips empty slots automatically
- Switching is instant (no animation delay)
- Can switch mid-cooldown (but cooldown continues)
- Preserves ammo/durability state

---

## Examples and Use Cases

### Example 1: Basic Melee Setup

```gdscript
# In Player script or initialization
func _ready():
    # Equip a knife to primary slot
    var knife = WeaponManager.create_weapon("RUSTY_KNIFE")
    WeaponManager.equip_weapon(knife, "PRIMARY_WEAPON")

    # Player can now attack with Q to switch to knife, Left Click to attack
```

### Example 2: Equipping Ranged Weapon with Ammo

```gdscript
func equip_gun():
    # Create weapon
    var pistol = WeaponManager.create_weapon("SCRAP_PISTOL")

    # Equip to secondary slot
    WeaponManager.equip_weapon(pistol, "SECONDARY_WEAPON")

    # Add ammo to inventory
    InventorySystem.add_item("SCRAP_BULLETS", 30)

    # Select ammo type for reloading
    pistol.selected_ammo_id = "SCRAP_BULLETS"

    # Switch to pistol
    WeaponManager.active_weapon_slot = "SECONDARY_WEAPON"
```

### Example 3: Custom Damage Modifier

```gdscript
# In Player script
func get_damage_modifier() -> float:
    var modifier = 1.0

    # Apply strength attribute bonus
    if has_attribute("strength"):
        modifier += attributes.strength * 0.1  # +10% per strength point

    # Apply buff effects
    if has_buff("damage_boost"):
        modifier += 0.5  # +50% damage

    return modifier
```

### Example 4: Listening for Combat Events

```gdscript
# In UI or game controller script
func _ready():
    # Listen to combat system
    CombatSystem.damage_dealt.connect(_on_damage_dealt)
    CombatSystem.enemy_killed.connect(_on_enemy_killed)

    # Listen to player combat
    var player_combat = get_tree().get_first_node_in_group("player").get_node("PlayerCombat")
    player_combat.hit_enemy.connect(_on_player_hit_enemy)

func _on_damage_dealt(attacker: Node, target: Node, amount: int):
    print("%s dealt %d damage to %s" % [attacker.name, amount, target.name])

func _on_enemy_killed(enemy: Node, killer: Node):
    print("%s killed %s!" % [killer.name, enemy.name])
    # Award XP, update quests, etc.
```

### Example 5: Creating Custom Weapon

```gdscript
# Create a custom weapon programmatically
func create_legendary_sword() -> Weapon:
    var weapon_data = {
        "name": "Neon Blade",
        "description": "A legendary plasma sword",
        "type": "MELEE",
        "tier": 5,
        "damage": 100,
        "attack_speed": 2.0,
        "range": 3.0,
        "durability": 500,
        "stats": {
            "critical_chance": 0.3,  # 30% crit chance
            "lifesteal": 0.15,        # 15% lifesteal
            "energy_damage": true
        }
    }

    return Weapon.new("LEGENDARY_NEON_BLADE", weapon_data)
```

### Example 6: Weapon Condition Warning

```gdscript
# In HUD or weapon display script
func update_weapon_durability_warning():
    var weapon = WeaponManager.get_active_weapon()
    if not weapon:
        return

    var durability_pct = weapon.get_durability_percentage()

    if durability_pct < 0.1:
        show_warning("WEAPON CRITICALLY DAMAGED!", Color.RED)
    elif durability_pct < 0.25:
        show_warning("Weapon Low Durability", Color.ORANGE)
```

---

## Troubleshooting

### Issue: Attacks Don't Register

**Symptoms:**
- Clicking attack button does nothing
- No damage numbers appear
- Console shows "can_attack=false"

**Solutions:**
1. Check if UI is blocking input:
   ```gdscript
   # PlayerCombat checks is_ui_blocking_input()
   # Make sure inventory/menus are closed
   ```

2. Verify attack cooldown has finished:
   ```gdscript
   # Check PlayerCombat.can_attack
   # Wait for cooldown timer to complete
   ```

3. Check weapon durability:
   ```gdscript
   var weapon = WeaponManager.get_active_weapon()
   if weapon and weapon.current_durability <= 0:
       print("Weapon is broken!")
   ```

### Issue: Ranged Weapons Won't Fire

**Symptoms:**
- "Need to reload!" message appears
- Gun has ammo in inventory but won't shoot

**Solutions:**
1. Select ammo type for weapon:
   ```gdscript
   weapon.selected_ammo_id = "SCRAP_BULLETS"
   ```

2. Ensure ammo is in inventory:
   ```gdscript
   if not InventorySystem.has_item("SCRAP_BULLETS"):
       print("No ammo in inventory!")
   ```

3. Reload the weapon:
   ```gdscript
   # Press R key or call:
   weapon.reload_from_inventory()
   ```

### Issue: Projectiles Don't Hit Enemies

**Symptoms:**
- Projectiles spawn but pass through enemies
- No damage dealt on collision

**Solutions:**
1. Check collision layers:
   ```gdscript
   # Enemy should be on layer 16 (Animals/Enemies)
   enemy.collision_layer = 16

   # Projectile should have mask including layer 16
   projectile.collision_mask = 1 + 2 + 16
   ```

2. Verify enemy has take_damage method:
   ```gdscript
   func take_damage(amount: int, attacker: Node = null):
       current_health -= amount
   ```

3. Check ProjectileSystem is loaded:
   ```gdscript
   if not has_node("/root/ProjectileSystem"):
       push_error("ProjectileSystem not in autoload!")
   ```

### Issue: Damage Numbers Don't Appear

**Symptoms:**
- Damage is dealt but no floating numbers

**Solutions:**
1. Verify Label3D is being created:
   ```gdscript
   # Check console for errors in create_damage_number()
   ```

2. Check camera is valid:
   ```gdscript
   var camera = get_viewport().get_camera_3d()
   if not camera:
       print("No camera found!")
   ```

3. Ensure scene can add children:
   ```gdscript
   # Damage numbers added to current_scene
   # Make sure scene is valid
   if not get_tree().current_scene:
       print("No current scene!")
   ```

### Issue: Weapon Switching Not Working

**Symptoms:**
- Q key doesn't switch weapons
- "No weapons equipped!" message

**Solutions:**
1. Verify weapons are equipped:
   ```gdscript
   print("Primary: ", WeaponManager.primary_weapon)
   print("Secondary: ", WeaponManager.secondary_weapon)
   ```

2. Check input action mapping:
   ```
   Project Settings → Input Map → "switch_weapon" = Q key
   ```

3. Ensure WeaponManager signals connected:
   ```gdscript
   WeaponManager.weapon_switched.connect(_on_weapon_switched)
   ```

### Issue: Melee Hits Behind Player

**Symptoms:**
- Can hit enemies behind the player
- Attack arc seems too wide

**Solutions:**
1. Adjust attack_arc property:
   ```gdscript
   # In PlayerCombat inspector
   attack_arc = 90.0  # Narrower arc (default is 120)
   ```

2. Modify arc check in code:
   ```gdscript
   # In check_melee_hit()
   var melee_arc = 90.0  # Change from 120.0
   if abs(angle_to_enemy) <= melee_arc / 2:
       enemies_hit.append(enemy)
   ```

### Issue: Reload Takes No Time

**Symptoms:**
- Reload completes instantly
- No reload animation/delay

**Solutions:**
1. Check reload_time in weapon data:
   ```json
   "reload_time": 2.0  // Should be > 0
   ```

2. Ensure await is working:
   ```gdscript
   # In reload_weapon()
   await get_tree().create_timer(weapon.reload_time).timeout
   ```

---

## Future Improvements

### Planned Features

#### 1. Aim Down Sights (ADS)
**Priority:** High
**Description:** Right-click to zoom camera and increase accuracy
- Reduce FOV when aiming
- Slow player movement
- Tighten bullet spread
- Add crosshair/reticle

**Implementation:**
```gdscript
# In PlayerCombat
var is_aiming: bool = false

func _input(event):
    if event.is_action_pressed("aim"):
        start_aiming()
    elif event.is_action_released("aim"):
        stop_aiming()

func start_aiming():
    is_aiming = true
    camera.fov = 50.0  # Zoom in
    player.movement_speed *= 0.5  # Slow down
```

#### 2. Bow Charge Mechanic
**Priority:** Medium
**Description:** Hold to charge bow for more damage
- Hold attack button to charge
- Visual feedback (arrow glow)
- Damage scales with charge time (1.0x to 2.0x)
- Release to fire

**Implementation:**
```gdscript
var bow_charge: float = 0.0
var max_bow_charge: float = 2.0

func _process(delta):
    if is_bow_charging:
        bow_charge += delta
        bow_charge = min(bow_charge, max_bow_charge)
        update_bow_visual()
```

#### 3. Weapon Attachments/Mods
**Priority:** Medium
**Description:** Equip scopes, grips, extended mags
- Scope: +50% range, +25% accuracy
- Extended Mag: +50% magazine size
- Fast Reload: -25% reload time
- Damage Booster: +15% damage

**Data Structure:**
```json
"mods": [
  {
    "id": "MOD_SCOPE",
    "name": "2x Scope",
    "stats": {
      "range_multiplier": 1.5,
      "accuracy_bonus": 0.25
    }
  }
]
```

#### 4. Realistic Melee Hit Detection
**Priority:** High
**Description:** Replace camera-based arc with weapon collision shapes
- Create hitbox mesh that follows weapon swing
- Use Area3D for detection during swing animation
- More realistic for attacks to sides/behind

**Implementation:**
```gdscript
# Add to weapon model
var weapon_hitbox: Area3D

func perform_melee_attack():
    weapon_hitbox.monitoring = true
    play_swing_animation()
    await animation_finished
    weapon_hitbox.monitoring = false
```

#### 5. Damage Types and Resistances
**Priority:** Low
**Description:** Physical, Energy, Plasma damage with resistances
- Enemies have resistance values
- Ammo/weapons deal specific damage types
- Calculate: `final_damage = base_damage * (1.0 - resistance)`

**Example:**
```gdscript
# Enemy stats
var resistances = {
    "physical": 0.2,  # 20% resistance
    "energy": 0.0,    # No resistance
    "plasma": -0.5    # 50% weakness
}
```

#### 6. Weapon Recoil and Spread
**Priority:** Medium
**Description:** Add recoil pattern and bullet spread
- Camera kick on shot
- Spread increases with rapid fire
- Different patterns per weapon

**Implementation:**
```gdscript
var current_spread: float = 0.0
var max_spread: float = 10.0

func apply_recoil():
    camera.rotate_x(deg_to_rad(-recoil_vertical))
    camera.rotate_y(deg_to_rad(recoil_horizontal))
    current_spread = min(current_spread + spread_increase, max_spread)
```

#### 7. Combat Audio
**Priority:** High
**Description:** Add sound effects for all combat actions
- Weapon swing/fire sounds
- Hit impact sounds (flesh, metal, wood)
- Reload sounds (click, chamber, slide)
- Critical hit sound effect

**Setup:**
```gdscript
@onready var audio_player: AudioStreamPlayer3D

func perform_attack():
    play_sound("weapon_swing")
    # ... attack logic
```

#### 8. Visual Effects Improvements
**Priority:** Medium
**Description:** Replace basic flashes with proper VFX
- Muzzle flash particles (ranged)
- Weapon trail effect (melee)
- Blood/spark particles on hit
- Shell casing ejection (guns)

#### 9. Damage Over Time (DOT)
**Priority:** Low
**Description:** Fire, poison, bleed effects
- Apply status effect on hit
- Tick damage over time
- Visual feedback (flames, dripping)

**Example:**
```gdscript
func apply_burn_damage(target: Node, duration: float):
    var burn_effect = DamageOverTime.new()
    burn_effect.setup(target, 5, 1.0, duration)  # 5 dmg/sec
    target.add_child(burn_effect)
```

#### 10. Weapon Skill Progression
**Priority:** Low
**Description:** Improve stats with weapon use
- Track weapon type usage
- Unlock perks per weapon type
- Example: "Rifle Mastery" +10% damage with rifles

### Known Limitations

1. **Camera-Only Melee Detection**: Current melee system uses camera direction only, not realistic weapon swing. Can hit enemies to sides that weapon model wouldn't reach.

2. **No Animation Integration**: Attacks don't sync with actual weapon model animations. Uses simple timers instead.

3. **Fixed Attack Arc**: 120° arc is hardcoded. Should vary per weapon type.

4. **No Weapon Models**: Weapons don't have 3D models shown in player's hands. Only abstracted through stats.

5. **Simple Damage Numbers**: Basic Label3D text. No fancy styling or animation.

6. **No Friendly Fire Prevention**: System exists but not fully tested for all scenarios.

7. **Projectile Physics Simplistic**: No gravity, wind, or drop. Straight-line trajectory only.

8. **No Armor System**: Damage reduction not implemented. All damage is direct.

### Performance Considerations

**Current Performance:**
- Melee: O(n) where n = enemies in scene (checks all)
- Ranged: Minimal overhead (physics engine handles)
- Damage numbers: Each creates a Label3D (can pool if needed)

**Optimization Opportunities:**
1. Spatial partitioning for melee checks (only check nearby enemies)
2. Object pooling for projectiles
3. Object pooling for damage numbers
4. Distance culling for combat calculations

---

**Last Updated:** 2025-10-01
**System Version:** 0.1.0
**Author:** Combat System Team
**Related Documentation:**
- See `COMBAT_CONTROLS.md` for player-facing controls guide
- See `ANIMAL_SYSTEM.md` for enemy/target setup

