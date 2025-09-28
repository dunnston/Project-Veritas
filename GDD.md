# Neon Wasteland 3D: Game Design Document

## Game Overview
**Title:** Neon Wasteland 3D
**Genre:** 3D Survival-Automation with Base Building and RPG Elements
**Platform:** PC (Windows, macOS, Linux)
**Engine:** Godot 4.3+
**Art Style:** Voxel/Low-poly with neon dystopian aesthetic

## Core Concept
A 3D reimagining of Neon Wasteland where players survive in a post-apocalyptic world by building and automating an underground bunker city while reclaiming the toxic surface world.

## Gameplay Pillars
1. **Exploration** - First/third-person exploration of procedurally generated wastelands (high level area), outer city desert (starting area), underground bunkers and eventually the dystopian city (end game)
2. **Automation** - 3D conveyor systems, pipes, and logistics networks
3. **Survival** - Manage oxygen, power, food, and shelter in hostile environment
4. **Combat** - Defend against mutants and raiders with crafted weapons
5. **Progression** - Tech tree unlocking from scavenged blueprints

## Camera & Controls
- **Primary View:** Third-person with orbital camera
- **Secondary View:** First-person for detailed building/interaction
- **Movement:** WASD + mouse look
- **Interaction:** Context-sensitive E key
- **Building:** Grid-based placement with preview system

## World Design
### Vertical Layers
1. **Surface** - Toxic wasteland, ruins, resource deposits
2. **Underground** - Player's expandable bunker base
3. **Deep Caverns** - Rare resources, ancient technology

### Grid System
- 1x1x1 meter voxel grid for building
- Snap-to-grid placement with rotation
- Multi-level construction support

## Systems Migration Plan
### Phase 1: Core Foundation
- GameManager (adapted for 3D scenes)
- EventBus (unchanged)
- SaveManager (extended for 3D data)
- TimeManager (unchanged)

### Phase 2: Player Systems
- InventorySystem (UI adapted for 3D)
- EquipmentManager (3D model swapping)
- AttributeManager (unchanged)
- SkillSystem (unchanged)

### Phase 3: World Systems
- BuildingSystem (3D grid placement)
- PowerSystem (3D cable rendering)
- OxygenSystem (volumetric visualization)
- ShelterSystem (3D boundary detection)

### Phase 4: Combat & AI
- CombatSystem (3D physics-based)
- ProjectileSystem (3D ballistics)
- SpawnerManager (3D spawn points)
- LootSystem (3D item drops)

### Phase 5: Environmental
- StormSystem (3D particle effects)
- InteriorDetectionSystem (3D volume detection)
- RoofVisibilityManager (3D transparency)

### Phase 6: Crafting & Items
- CraftingManager (unchanged backend)
- BuildingManager (3D placement)
- ItemDropManager (3D physics drops)
- AmmoManager (unchanged)
- WeaponManager (3D models)

## Technical Specifications
- **Renderer:** Forward+ for performance
- **Physics:** Godot 3D physics with layers
- **Networking:** Future multiplayer support structure
- **Performance Target:** 60 FPS on GTX 1060

## Art Direction
- Voxel/low-poly models with PBR materials
- Neon accent lighting (cyan, magenta, yellow)
- Fog and atmospheric effects for depth
- Modular building pieces for variety

## Visual Style References
- **Environment:** Cyberpunk wasteland with industrial ruins
- **Buildings:** Modular tech-industrial with neon accents
- **UI:** Holographic interfaces with glitch effects
- **Lighting:** Harsh surface sunlight, moody underground ambiance

## Audio Design
- **Music:** Synthwave/darksynth soundtrack
- **Ambiance:** Industrial drones, distant storms, mechanical hums
- **SFX:** Satisfying building clicks, weapon impacts, resource collection

## Progression Systems
### Technology Tree
- **Tier 1:** Basic survival (oxygen, shelter, simple tools)
- **Tier 2:** Automation (conveyors, basic machines)
- **Tier 3:** Advanced tech (drones, turrets, advanced processing)
- **Tier 4:** Experimental (teleportation, energy weapons)

### Player Skills
- **Engineering:** Building efficiency, automation speed
- **Combat:** Weapon handling, damage resistance
- **Survival:** Resource efficiency, environmental resistance
- **Exploration:** Movement speed, scanner range

## Resource Types
### Primary Resources
- **Scrap Metal:** Basic building material
- **Electronics:** Advanced components
- **Chemicals:** Fuel and processing
- **Biomatter:** Food and medicine

### Energy Resources
- **Power Cells:** Portable energy
- **Solar Panels:** Renewable but surface-only
- **Geothermal:** Deep underground taps
- **Nuclear:** End-game power generation

## Enemy Types
### Surface Threats
- **Raiders:** Human survivors, use weapons and tactics
- **Mutants:** Fast, melee-focused corrupted humans
- **Drones:** Automated defense systems gone rogue

### Underground Threats
- **Cave Dwellers:** Adapted to darkness, ambush tactics
- **Ancient Machines:** Pre-war automated guardians
- **Toxic Fauna:** Mutated underground creatures

## Building Types
### Infrastructure
- **Foundations:** Basic building platforms
- **Walls/Doors:** Modular construction pieces
- **Power Systems:** Generators, batteries, cables
- **Life Support:** Oxygen generators, air filters

### Production
- **Extractors:** Resource gathering from deposits
- **Refiners:** Process raw materials
- **Assemblers:** Craft complex items
- **Storage:** Various container types

### Defense
- **Turrets:** Automated defense weapons
- **Shields:** Energy barriers
- **Traps:** Environmental hazards
- **Walls:** Fortified barriers

## Multiplayer Considerations (Future)
- **Co-op:** 2-4 players sharing a base
- **PvP Zones:** Contested resource areas
- **Trading:** Player-to-player economy
- **Raids:** Attack/defend other bases

## Performance Optimization Strategy
- **LOD System:** Multiple detail levels for models
- **Occlusion Culling:** Hide unseen geometry
- **Instance Rendering:** Batch similar objects
- **Dynamic Loading:** Stream world chunks

## Save System
- **World Data:** Terrain modifications, building placement
- **Player Data:** Inventory, skills, attributes
- **System States:** All manager states preserved
- **Version Migration:** Support for save compatibility

## Development Milestones
### Milestone 1: Core Movement (Current)
- Basic player controller
- Camera system
- Test environment

### Milestone 2: Building Foundation
- Grid system implementation
- Basic building placement
- Simple structures

### Milestone 3: Resource Loop
- Resource gathering
- Basic crafting
- Inventory system

### Milestone 4: Survival Mechanics
- Oxygen system
- Power management
- Day/night cycle

### Milestone 5: Combat
- Enemy AI
- Weapon system
- Damage/health

### Milestone 6: Automation
- Conveyor systems
- Machine connections
- Resource flow

### Milestone 7: Polish
- Effects and particles
- Sound implementation
- UI refinement

## Risk Mitigation
### Technical Risks
- **Performance:** Regular profiling, LOD implementation
- **Module Migration:** Adapter pattern for 2D->3D
- **Save Compatibility:** Versioned save system

### Design Risks
- **Scope Creep:** Phased implementation plan
- **Complexity:** Start simple, layer systems
- **Balance:** Extensive playtesting phases