# New Building System - Template Placement Workflow

## Overview
The building system has been redesigned to allow players to place multiple building previews (templates) before committing resources. This provides a better planning experience similar to games like Rust and Valheim.

## How It Works

### Old Workflow
1. Select building from menu
2. Place preview (green = valid, red = invalid)
3. Click to place → **resources consumed immediately**
4. Must reopen menu for each piece

### New Workflow
1. Select building from menu
2. Place preview (green = valid, red = invalid)
3. Click to place → **creates light blue template** (no resources consumed)
4. Can continue placing more templates without reopening menu
5. Press ESC to exit placement mode
6. Walk up to any template → **Hold E for 5 seconds**
7. Progress bar fills → template converts to real building → **resources consumed**

## Visual States
- **Red Preview**: Invalid placement (overlapping, bad location)
- **Green Preview**: Valid placement (can place template here)
- **Light Blue Template**: Placed but unbuilt preview
  - Transparent (can walk through)
  - Glowing light blue color
  - Can be built by holding E

## Key Features

### Template Placement
- Templates are free to place (no resource cost)
- Can place unlimited templates to plan your base
- Templates show exactly where buildings will be
- Player can walk through templates (no collision)

### Hold-to-Build Mechanic
- Approach any template
- Hold E for 5 seconds
- Progress bar shows build progress
- Resources consumed only when build completes
- If you can't afford it, you get an error message

### Multiple Placements
- Building mode stays active after placing a template
- Place floors, then walls, then ceiling without reopening menu
- Press ESC or C to exit placement mode

## Files Modified

### Core System Files
- **`scripts/buildings/BuildingTemplate.gd`** (NEW)
  - Represents placed but unbuilt templates
  - Light blue transparent material
  - Walkthrough collision (none)
  - Tracks building data and cost

- **`scripts/systems/BuildingSystem.gd`**
  - `attempt_place_building()`: Now places templates instead of real buildings
  - `place_building_template()`: Creates template nodes
  - `_on_template_construction_completed()`: Converts template to real building
  - Resource consumption moved from placement to construction

- **`scripts/player/PlayerAnimated3D.gd`**
  - `find_nearest_building_template()`: Detects nearby templates
  - `start_building_template()`: Begins hold-to-build
  - `complete_building_template()`: Finishes construction
  - Build progress tracking (0-5 seconds)

### UI Files
- **`scripts/ui/BuildProgressUI.gd`** (NEW)
  - Shows progress bar when building
  - Displays building name
  - Auto-shows/hides based on progress

## Setup Instructions

### Adding the Build Progress UI to Your Scene

1. Open your main game scene (e.g., `demo_scene.tscn`)

2. Find or create a UI layer (usually a CanvasLayer for HUD)

3. Add a new Control node as a child, name it "BuildProgressUI"

4. Set the Control node's layout to fill the screen:
   - Anchor Preset: Full Rect
   - Grow Horizontal: Both
   - Grow Vertical: Both

5. Attach the script `res://scripts/ui/BuildProgressUI.gd`

6. Add these child nodes to BuildProgressUI:
   ```
   BuildProgressUI (Control)
   └─ CenterContainer
      └─ VBoxContainer
         ├─ ProgressBar (name: "ProgressBar")
         └─ Label (name: "BuildingLabel")
   ```

7. Configure the ProgressBar:
   - Min Value: 0
   - Max Value: 100
   - Custom Minimum Size: (300, 30) or larger

8. Configure the Label:
   - Horizontal Alignment: Center
   - Add theme font size override if needed (e.g., 20)

### Testing the System

1. Press `L` to add debug resources (SCRAP_METAL, WOOD_SCRAPS, etc.)
2. Open build menu (B key)
3. Select "Basic Floor"
4. Click to place multiple floor templates (light blue, walkthrough)
5. Select "Basic Wall"
6. Place walls around your floors
7. Press ESC to exit placement mode
8. Walk up to a template
9. Hold E - watch the progress bar
10. After 5 seconds, template becomes a real building

## Debug Commands
- `L`: Add 100 SCRAP_METAL, 100 WOOD_SCRAPS, 50 METAL_SHEETS, 50 ELECTRONICS
- `X`: Toggle demolition mode
- `B`: Open build menu
- `ESC` or `C`: Cancel building placement mode

## Implementation Details

### Resource Checking
- Templates can be placed even if you can't afford them
- Affordability is checked when you try to build (hold E)
- This allows planning without having all resources upfront

### Collision Handling
- Templates have no physical collision
- Player can walk through templates freely
- Preview collision detection still works (shows red if overlapping)

### Template Tracking
- BuildingSystem connects to template signals
- When construction completes, template is removed
- Real building is placed at template's position with same rotation

## Future Enhancements (Not Yet Implemented)

- [ ] Right-click template to cancel/remove it
- [ ] Show resource cost in UI when hovering over template
- [ ] Visual indication when you can't afford a template
- [ ] Sound effects for template placement and construction
- [ ] Particle effects during construction
- [ ] Blueprint/grid visualization mode
- [ ] Save/load templates
- [ ] Template presets (save entire base designs)

## Troubleshooting

**Q: Templates aren't showing up after placement**
A: Check that BuildingTemplate.gd is in the correct path and autoloaded classes are registered

**Q: Hold E doesn't work on templates**
A: Ensure templates are in the "building_template" and "interactable" groups (automatic in BuildingTemplate._ready())

**Q: Progress bar doesn't show**
A: Check that BuildProgressUI is added to your scene and player's build_progress_changed signal is connected

**Q: Can't afford message but I have resources**
A: Check recipes.json for correct resource IDs (e.g., "SCRAP_METAL" not "scrap_metal")

**Q: Templates have collision (can't walk through)**
A: Templates intentionally have no collision. If blocked, it's likely a real building nearby.

## Migration Notes

If you have existing saves or placed buildings:
- Old buildings placed before this update are unaffected
- New placement system only applies to newly placed buildings
- Templates are NOT saved (intentionally - they're ephemeral planning tools)
- Consider adding template persistence if you want players to resume base planning between sessions
