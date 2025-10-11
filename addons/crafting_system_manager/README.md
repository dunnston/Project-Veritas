# Neon Wasteland Crafting System Manager Plugin

A comprehensive Godot 4 editor plugin for managing items, recipes, and crafting benches in your game project.

## Features

### 📦 Items Management
- **Add/Edit Items**: Create new items with customizable properties
- **Properties**: Name, description, icon path, stack size, category
- **Categories**: Material, component, tool, equipment, consumable, power, organic
- **Real-time editing**: Changes update instantly in the UI

### 🔨 Recipe Management
- **Complete Recipe Editor**: Create crafting recipes with ingredients and outputs
- **Flexible Ingredients**: Add/remove ingredients with dynamic quantities
- **Multiple Outputs**: Support for recipes that produce multiple items
- **Recipe Properties**: Craft time, workbench requirements, categories
- **Integration**: Automatically validates ingredients against existing items

### 🏭 Bench Management (Buildings)
- **Building Properties**: Size, health, categories, placement rules
- **Grid System**: Configure building dimensions (width x height)
- **Categories**: Crafting, storage, power, production, structure, emergency
- **Cost System**: Define building costs and refund amounts

### 📊 Export & Import
- **Data Export**: Export all data, items only, or recipes only to JSON
- **Import System**: Import data from external JSON files
- **Backup & Share**: Easy data backup and sharing between projects
- **Timestamp Tracking**: Export includes timestamps and version info

### 🔍 Data Validation
- **Comprehensive Validation**: Check for missing fields, invalid references
- **Issue Detection**: Find broken recipe references, missing properties
- **Auto-Fix**: Automatically fix common data issues
- **Real-time Feedback**: Immediate validation results and suggestions

## Installation & Usage

### 1. Enable the Plugin
1. Copy the `crafting_system_manager` folder to your project's `addons/` directory
2. Go to **Project → Project Settings → Plugins**
3. Find "Crafting System Manager" and enable it
4. The plugin dock will appear in the editor (usually on the left side)

### 2. Using the Plugin

#### Items Tab
- **Add New Item**: Click "Add New Item" to create a new item
- **Edit Properties**: Select an item from the list to edit its properties
- **ID Management**: Change item IDs (updates all references automatically)
- **Categories**: Assign items to categories for better organization

#### Recipes Tab
- **Create Recipes**: Add new crafting recipes with the "Add New Recipe" button
- **Ingredients**: Click "Add Ingredient" to add required materials
- **Outputs**: Define what the recipe produces (can be multiple items)
- **Recipe Types**: Set category, craft time, and workbench requirements
- **Dynamic Editing**: Add/remove ingredients and outputs on the fly

#### Benches Tab
- **Building Management**: Create and edit craftable buildings/benches
- **Size Configuration**: Set building dimensions for grid placement
- **Properties**: Health, category, movement/placement blocking
- **Integration**: Automatically integrates with your building system

#### Export Tab
- **Export Options**: 
  - Export All Data: Complete game data export
  - Export Items Only: Just the items/resources
  - Export Recipes Only: Just the crafting recipes
- **Import Data**: Import JSON data from external sources
- **Validation Tools**: 
  - Validate Data: Check for issues and inconsistencies
  - Fix Common Issues: Automatically repair common problems
- **Results Panel**: View detailed operation results and error reports

### 3. Data Integration

The plugin automatically integrates with your existing game data files:
- `res://data/resources.json` - Items/resources
- `res://data/recipes.json` - Crafting recipes  
- `res://data/buildings.json` - Buildings/benches

Changes are saved directly to these files when you click "Save All Changes".

## Tips & Best Practices

### Item Management
- Use consistent naming conventions (e.g., ALL_CAPS for IDs)
- Set appropriate stack sizes based on item rarity
- Use descriptive categories for better organization

### Recipe Design
- Start with simple recipes and build complexity gradually
- Validate all recipes after creation to ensure item references exist
- Use reasonable craft times based on item complexity
- Consider workbench requirements for advanced items

### Data Safety
- Use the Export feature to backup your data regularly
- Validate data after making bulk changes
- Use the auto-fix feature to resolve common issues quickly

### Workflow Tips
- Plan your item hierarchy before creating recipes
- Use the validation tools frequently during development
- Export data when sharing with team members
- Test recipes in-game after major changes

## Integration with Game Systems

The plugin works seamlessly with the existing Neon Wasteland game systems:
- **ResourceManager**: Automatically updates when items are modified
- **CraftingManager**: Recipe changes integrate with the crafting system
- **BuildingManager**: Building data syncs with the placement system

## Troubleshooting

### Plugin Won't Enable
- Ensure the plugin is in the correct directory: `addons/crafting_system_manager/`
- Check that `plugin.cfg` exists and is properly formatted
- Try disabling and re-enabling the plugin

### Data Not Saving
- Check file permissions in the `data/` directory
- Ensure JSON files are not open in external editors
- Use the validation tools to check for data format issues

### Missing Items in Dropdowns
- Use "Validate Data" to check for missing references
- Ensure all referenced items exist in the resources data
- Use "Fix Common Issues" to automatically resolve problems

## Support

This plugin is designed specifically for the Neon Wasteland project and integrates with its existing data structures and systems. For issues or feature requests, consult the main project documentation or development team.

---

**Version**: 1.0.0  
**Compatibility**: Godot 4.3+  
**Project**: Neon Wasteland: Automated Survival