# Combat System Controls

## Overview
The combat system supports melee (fists/knives) and ranged (guns/bows) weapons with damage numbers, critical hits, and weapon switching.

## Basic Controls

### Combat Actions
- **Left Click** - Attack with equipped weapon or fists
- **Right Click** - Aim (planned for future implementation)
- **R** - Reload current weapon (guns and bows)

### Weapon Switching
- **X** - Cycle between primary and secondary weapons
- **Z** - Equip primary weapon slot
- **C** - Equip secondary weapon slot
- **V** - Unequip weapon (use fists)

## Weapon Types

### Fists (Unarmed)
- **Damage**: 5 base damage
- **Range**: 50 units
- **Speed**: Fast
- **No ammo required**

### Melee Weapons (Knives, Swords)
- **Damage**: Varies by weapon (15-50+)
- **Range**: 1.5-3 units
- **Speed**: Medium to Fast
- **Critical Hits**: Some weapons have crit chance
- **No ammo required**

### Ranged Weapons - Guns
- **Damage**: Varies by weapon (20-60+)
- **Range**: Long (30-100 units)
- **Speed**: Fast fire rate
- **Requires**: Ammunition in magazine
- **Reload**: Press R when magazine is empty
- **Ammo Types**: Bullets, Energy Cells, Plasma

### Ranged Weapons - Bows
- **Damage**: Varies by bow (25-50+)
- **Range**: Long (40-80 units)
- **Speed**: Slower than guns
- **Requires**: Arrows (reload after each shot)
- **Reload**: Press R after each shot
- **Charge Mechanic**: Hold to draw, release to fire (planned)

## Visual Feedback

### Damage Numbers
- **Orange Numbers**: Normal damage
- **Red Numbers (Larger)**: Critical hit damage
- Numbers float upward and fade out
- Random position offset prevents stacking

### Hit Effects
- **Melee**: White flash on player
- **Ranged**: Yellow-white flash on player
- **Reload**: Cyan "RELOADING..." message

### Weapon Switch
- **Blue Flash**: Weapon switched successfully
- **White Flash**: Weapon unequipped (fists)
- Console message shows equipped weapon

## Weapon Stats

### Damage Calculation
```
Base Damage × Durability Modifier × Player Modifiers = Final Damage
```

### Critical Hits
- Triggered by weapon's `critical_chance` stat
- Deals 1.5× damage
- Displayed in red with larger font

### Durability
- Weapons lose 1 durability per attack
- Damage reduced as durability decreases
- 0 durability = weapon breaks (can't attack)

## Ammunition System

### Magazine System (Guns)
- Each gun has a magazine size (e.g., 10 rounds)
- Current ammo shown in HUD
- Empty magazine prevents firing
- Press R to reload from inventory

### Arrow System (Bows)
- Magazine size of 1 (one arrow at a time)
- Must reload after every shot
- Quick reload time (~0.8 seconds)

### Ammo Types
- **SCRAP_BULLETS**: Basic bullets for pistols
- **FIRE_BULLETS**: Enhanced bullets (more damage)
- **WOOD_ARROWS**: Basic arrows for bows
- **STEEL_ARROWS**: Enhanced arrows (more damage)
- **ENERGY_CELLS**: Energy weapon ammo
- **PLASMA_CHARGES**: Plasma weapon ammo

## Testing in Demo Scene

### Auto-Equipped Weapons
The CombatTestHelper automatically equips:
1. **Primary Slot**: Scrap Knife (15 dmg, 15% crit)
2. **Secondary Slot**: Scrap Pistol (20 dmg, 10 rounds)
3. **Inventory**: 100 bullets, 50 arrows

### Test Sequence
1. **Test Fists**: Press V to unequip, punch rabbits
2. **Test Knife**: Press Z to equip primary, attack deer
3. **Test Gun**: Press C to equip secondary, shoot boars
4. **Test Reload**: Empty magazine, press R to reload
5. **Test Switching**: Press X to cycle weapons mid-combat

## Combat Tips

### Melee Combat
- Get close to targets (within 1-3 units)
- Face the target directly
- Watch for crit hits (red numbers)
- Melee weapons don't use ammo

### Ranged Combat
- Aim at target with mouse
- Check ammo counter before engaging
- Reload in safe locations
- Keep distance from aggressive animals

### Weapon Management
- Primary slot for main weapon
- Secondary slot for backup weapon
- Quick switch with X in emergencies
- Use fists to save weapon durability

### Fighting Animals
- **Passive (Rabbits/Deer)**: Will flee, chase and attack
- **Neutral (Boars)**: Wait for them to attack first
- **Aggressive (Wolves/Bears)**: Attack from range if possible

## Troubleshooting

### "Need to reload!" message
- Press R to reload
- Check inventory for compatible ammo
- Weapon may need specific ammo type selected

### "No ammo to reload!" message
- Inventory is empty of compatible ammo
- Craft or find more ammunition
- Switch to melee weapon

### Weapon not attacking
- Check if weapon is equipped (press Z or C)
- Check weapon durability (may be broken)
- Check if UI is open (close with ESC/Tab)
- For guns, check if ammo in magazine

### Damage numbers not showing
- Animals may already be dead
- Check if you're within attack range
- Verify weapon is actually hitting (angle/distance)

## Advanced Features (Planned)

### Bow Charge Mechanic
- Hold left click to draw bow
- Longer draw = more damage
- Release to fire charged shot
- Visual feedback for charge level

### Aim Down Sights
- Right click to aim
- Reduced FOV
- Increased accuracy
- Slower movement

### Weapon Mods
- Scopes for accuracy
- Extended magazines
- Damage upgrades
- Fire rate modifications

---

**Last Updated**: 2025-10-01
**System Version**: 0.1.0
