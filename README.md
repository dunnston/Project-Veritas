# Project Veritas 3D

A dystopian survival-automation game built with Godot 4.3, featuring a neon-drenched wasteland where players must survive, build, and automate in a harsh post-apocalyptic world.

## 🎮 Overview

Project Veritas 3D is a 3D reimagining of a survival-automation game, transitioning from 2D to an immersive 3D environment. Players navigate a dystopian world filled with environmental dangers, resource scarcity, and opportunities for automation.

## 🚀 Features

- **Third-person character controller** with smooth camera movement
- **Full animation system** supporting walk, run, jump, crouch, and idle states
- **Combat system** with melee and ranged weapons, ammunition, and durability
- **Animal spawning** with AI behaviors (passive, neutral, aggressive)
- **Inventory system** with drag-and-drop UI and equipment slots
- **Modular architecture** designed for gradual migration from 2D systems
- **Neon dystopian aesthetic** with atmospheric lighting and effects
- **Grid-based building system** (in development)
- **Resource management and automation** (coming soon)

## 🛠️ Technical Stack

- **Engine**: Godot 4.3+ with Forward+ renderer
- **Language**: GDScript
- **Architecture**: Modular singleton-based system
- **Animation**: Mixamo-compatible character animations
- **Platform**: Windows/Linux/Mac (cross-platform)

## 📁 Project Structure

```
neon-wasteland-3d/
├── assets/          # Game assets (models, textures, audio)
├── scenes/          # Godot scenes
│   ├── player/      # Player character scenes
│   └── world/       # World and environment scenes
├── scripts/         # GDScript files
│   └── player/      # Player controller scripts
├── GDD.md          # Game Design Document
└── CLAUDE.md       # Development guidelines
```

## 🎯 Development Status

### Current Features
- ✅ Third-person character controller with camera pivot
- ✅ Animation system with Mixamo support
- ✅ Combat system (melee and ranged weapons)
- ✅ Weapon manager with switching and durability
- ✅ Ammunition system with reload mechanics
- ✅ Inventory system with UI
- ✅ Animal spawning with template-based AI
- ✅ AI behaviors (passive, neutral, aggressive)
- ✅ Loot system with drop tables
- ✅ Demo environment with test geometry

### In Progress
- 🔄 Survival stats (hunger, thirst, oxygen)
- 🔄 Migration of 2D systems to 3D
- 🔄 Grid-based building system
- 🔄 Resource gathering mechanics

### Planned
- 📋 Crafting system
- 📋 Automation mechanics
- 📋 Environmental hazards
- 📋 Day/night cycle
- 📋 Weather system
- 📋 Advanced weapon attachments
- 📋 Animal pack behaviors

## 🎮 Controls

### Movement
- **WASD** - Move character
- **Mouse** - Camera rotation
- **Space** - Jump
- **Shift** - Sprint
- **Ctrl** - Crouch

### Combat
- **Left Click** - Attack with equipped weapon or fists
- **Q** - Switch weapons (Primary → Secondary → Fists)
- **R** - Reload ranged weapon

### UI
- **Tab** - Toggle inventory
- **E** - Interact
- **Escape** - Menu/Cursor toggle

See `docs/COMBAT_CONTROLS.md` for detailed combat guide.

## 🔧 Setup

1. Install [Godot 4.3+](https://godotengine.org/)
2. Clone this repository
3. Open the project in Godot
4. Run the demo scene: `scenes/world/demo_scene.tscn`

## 📚 Documentation

### Developer Documentation
- **CLAUDE.md** - Development guidelines and workflow
- **GDD.md** - Game Design Document
- **GITHUB.md** - GitHub PR automation guide

### System Documentation
- **docs/COMBAT_SYSTEM.md** - Complete combat system reference with API docs
- **docs/COMBAT_CONTROLS.md** - Player-facing combat controls guide
- **docs/ANIMAL_SYSTEM.md** - Animal creation and spawning tutorial
- **docs/SPAWNING_SYSTEM.md** - Complete spawning system reference with API docs

### Migration Documentation
- **MIGRATION_COMPLETED.md** - Completed 2D to 3D migrations

## 📝 Development Notes

- The `3d Assets/` folder is excluded from version control due to size
- Character animations use a processed GLB file from Blender
- The project is designed for gradual migration from an existing 2D codebase
- Follow the GitHub PR automation workflow in `GITHUB.md` for all features
- Use conventional commit format for all commits

## 🤝 Contributing

This project is currently in early development. Contribution guidelines will be added as the project matures.

## 📄 License

[License information to be added]

---

*Built with Godot 4.3 - A dystopian future awaits in the neon wasteland*
