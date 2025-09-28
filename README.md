# Project Veritas 3D

A dystopian survival-automation game built with Godot 4.3, featuring a neon-drenched wasteland where players must survive, build, and automate in a harsh post-apocalyptic world.

## 🎮 Overview

Project Veritas 3D is a 3D reimagining of a survival-automation game, transitioning from 2D to an immersive 3D environment. Players navigate a dystopian world filled with environmental dangers, resource scarcity, and opportunities for automation.

## 🚀 Features

- **Third-person character controller** with smooth camera movement
- **Full animation system** supporting walk, run, jump, crouch, and idle states
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
- ✅ Basic third-person character controller
- ✅ Animation system with Mixamo support
- ✅ Demo environment with test geometry
- ✅ Movement controls (WASD + mouse)
- ✅ Jump, sprint, and crouch mechanics

### In Progress
- 🔄 Migration of 2D systems to 3D
- 🔄 Grid-based building system
- 🔄 Resource gathering mechanics

### Planned
- 📋 Inventory system
- 📋 Crafting system
- 📋 Automation mechanics
- 📋 Environmental hazards
- 📋 Day/night cycle
- 📋 Weather system

## 🎮 Controls

- **WASD** - Movement
- **Mouse** - Camera rotation
- **Space** - Jump
- **Shift** - Sprint
- **Ctrl** - Crouch
- **E** - Interact (placeholder)
- **Escape** - Menu/Cursor toggle

## 🔧 Setup

1. Install [Godot 4.3+](https://godotengine.org/)
2. Clone this repository
3. Open the project in Godot
4. Run the demo scene: `scenes/world/demo_scene.tscn`

## 📝 Development Notes

- The `3d Assets/` folder is excluded from version control due to size
- Character animations use a processed GLB file from Blender
- The project is designed for gradual migration from an existing 2D codebase
- See `GDD.md` for detailed game design documentation
- See `CLAUDE.md` for development guidelines and migration tracking

## 🤝 Contributing

This project is currently in early development. Contribution guidelines will be added as the project matures.

## 📄 License

[License information to be added]

---

*Built with Godot 4.3 - A dystopian future awaits in the neon wasteland*
