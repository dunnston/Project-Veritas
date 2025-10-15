# Building System Overhaul - Gap-Free Base Building

**Status**: In Progress
**Started**: 2025-10-14
**Goal**: Implement Unity-style grid-based building system with perfect edge snapping and zero visible gaps

---

## 🎯 Problem Statement

Current building system has visible gaps between building pieces:
- Floors don't align perfectly (gaps between tiles)
- Walls float or embed into floors (not flush with edges)
- Roofs have gaps at wall tops (z-fighting or spacing issues)
- Door frames don't create perfect openings for doors
- Buildings look incomplete and unprofessional

**Root Cause**: Mixing grid units with world units, missing geometry offset compensation, and lack of true grid-based tracking.

---

## 🔍 Analysis Summary

### Unity System Insights

The working Unity example uses:

1. **Three-Tier Object System**:
   - **GridObjects**: Floors/roofs placed at grid cell centers
   - **EdgeObjects**: Walls/door frames on tile edges via `FloorEdgePosition` markers
   - **LooseObjects**: Free placement anywhere

2. **Critical Pattern**:
   ```csharp
   Vector3 worldPos = grid.GetWorldPosition(x, z)
       + new Vector3(rotationOffset.x, 0, rotationOffset.y) * grid.GetCellSize();
   ```
   - Uses ScriptableObject `width` and `height` to calculate `rotationOffset`
   - Grid cell size matches object dimensions (1m, 5m, 10m)
   - Edge objects are **children of floor objects**
   - Position calculated from grid + offset, not world space snapping

3. **Key Files**:
   - `HouseBuildingSystem.cs` - Main building logic with 3 placement types
   - `PlacedObjectTypeSO.cs` - Width/height definitions, rotation offsets
   - `FloorPlacedObject.cs` - Manages edge object children
   - `FloorEdgePosition.cs` - Markers for NORTH/SOUTH/EAST/WEST edges

### Current Godot Issues

**Issue 1: Size Inconsistency** (BuildingSystem.gd:86-96)
- JSON: `"size": {"x": 1.0, "y": 1.0}` (grid units)
- Code: `Vector3(5, 5, 0.1)` (world meters)
- **Problem**: Grid units ≠ World units!

**Issue 2: Geometry Offset**
- SimpleSpace GLB meshes: Geometry at local `(-2.5, 0, -2.5)` from root
- System positions root, but visuals are offset
- Result: 5m tiles with mesh shifted, creating gaps

**Issue 3: Wall Snapping** (BuildingPreview3D.gd:398-443)
- Hardcoded `wall_thickness = 0.2m` but SimpleSpace = `0.1m`
- Edge calc doesn't use actual AABB dimensions
- Assumes centered mesh, but GLB root at corner

**Issue 4: No True Grid**
- World-space snapping, not grid coordinate tracking
- Unity: `Vector2Int(x, z)` grid, Godot: `Vector3` world
- Can't detect "same tile, different edge"

---

## 📋 Implementation Plan

### ✅ Phase 0: Setup & Documentation
- [x] Create tracking document (this file)
- [x] Create todo list for progress tracking
- [ ] Review Unity scripts in detail
- [ ] Map SimpleSpace prefab geometries

### 🔲 Phase 1: True Grid Foundation

**Goal**: Separate grid coordinates from world positions

- [ ] **1.1: Add Grid Data Structures** (BuildingSystem.gd)
  ```gdscript
  var grid_cell_size: float = 5.0  # SimpleSpace tile size
  var grid_origin: Vector3 = Vector3.ZERO  # World position of grid (0,0,0)
  var placed_grid_objects: Dictionary = {}  # Key: "x,y,z", Value: building data
  ```

- [ ] **1.2: Implement Coordinate Conversion**
  ```gdscript
  func world_to_grid(world_pos: Vector3) -> Vector3i:
      # Convert world position to grid coordinates
      var relative = world_pos - grid_origin
      return Vector3i(
          int(round(relative.x / grid_cell_size)),
          int(round(relative.y / grid_cell_size)),
          int(round(relative.z / grid_cell_size))
      )

  func grid_to_world(grid_pos: Vector3i) -> Vector3:
      # Convert grid coordinates to world position (cell center)
      return grid_origin + Vector3(
          grid_pos.x * grid_cell_size,
          grid_pos.y * grid_cell_size,
          grid_pos.z * grid_cell_size
      )
  ```

- [ ] **1.3: Test Coordinate Conversion**
  - Create debug visualization showing grid overlay
  - Verify round-trip conversion: `world → grid → world`
  - Test with various positions and grid sizes

**Notes**:

**Blockers**:

---

### 🔲 Phase 2: Building Data & Dimensions

**Goal**: Load actual mesh geometry and store proper dimensions

- [ ] **2.1: Create Mesh Inspector Utility**
  ```gdscript
  func inspect_building_mesh(scene_path: String) -> Dictionary:
      # Load GLB prefab and extract:
      # - AABB dimensions (actual visual size)
      # - Mesh local position (offset from root)
      # - Collision shape size
      var scene = load(scene_path)
      if not scene: return {}

      var instance = scene.instantiate()
      var mesh_instance = instance.get_node_or_null("Mesh")
      if not mesh_instance or not mesh_instance.mesh:
          instance.queue_free()
          return {}

      var aabb = mesh_instance.mesh.get_aabb()
      var mesh_local_pos = mesh_instance.position

      var result = {
          "aabb_size": aabb.size,
          "aabb_center": aabb.get_center(),
          "mesh_local_position": mesh_local_pos,
          "geometry_offset": mesh_local_pos + aabb.get_center()
      }

      instance.queue_free()
      return result
  ```

- [ ] **2.2: Update Building Data Structure**
  ```gdscript
  building_data[building_id] = {
      "name": "Basic Floor",
      "grid_size": Vector2i(1, 1),  # Grid units from JSON
      "world_size": Vector3(5, 5, 0.1),  # Actual meters (AABB)
      "geometry_offset": Vector3(-2.5, 0, -2.5),  # Where mesh visual is
      "wall_thickness": 0.1,  # For edge calculations
      "height": 5.0,  # For vertical placement (walls)
      "scene_path": "res://path/to/prefab.tscn",
      "icon_path": "res://path/to/icon.png"
  }
  ```

- [ ] **2.3: Update load_building_data() Function**
  - For each building in JSON:
    - Load grid size from JSON `"size": {"x": 1, "y": 1}`
    - If scene_path exists, call `inspect_building_mesh()`
    - Store both grid size and actual world dimensions
    - Calculate geometry offset for placement correction
  - Special cases:
    - `basic_floor`: SimpleSpace SM_Env_Floor_01
    - `basic_wall`: SimpleSpace SM_Env_Wall_02
    - `basic_roof`: SimpleSpace SM_Env_Ceiling_01
    - `door_frame`: SciFiSpace SM_Bld_Wall_Doorframe_01

- [ ] **2.4: Print Validation Report**
  - After loading all buildings, print summary:
    ```
    Building Data Loaded:
    - basic_floor: Grid(1x1) World(5.0x5.0x0.1) Offset(-2.5, 0, -2.5)
    - basic_wall: Grid(1x1) World(5.0x5.0x0.1) Offset(-2.5, 0, 0) Thickness(0.1)
    - basic_roof: Grid(1x1) World(5.0x5.0x0.1) Offset(-2.5, 0, -2.5)
    ```

**Notes**:
- SimpleSpace prefabs have mesh at local (-2.5, 0, -2.5) for floors/walls
- SciFiSpace door frame has different offset pattern
- Need to handle BoxMesh fallbacks for buildings without GLB

**Blockers**:

---

### 🔲 Phase 3: Edge-Based Placement System

**Goal**: Implement proper edge snapping for walls and door frames

- [ ] **3.1: Define Edge System**
  ```gdscript
  enum TileEdge {
      NORTH,   # +Z edge
      SOUTH,   # -Z edge
      EAST,    # +X edge
      WEST     # -X edge
  }

  func get_edge_from_rotation(rotation_deg: int) -> TileEdge:
      var normalized = int(rotation_deg) % 360
      if normalized < 0: normalized += 360

      if normalized >= 315 or normalized < 45:
          return TileEdge.NORTH
      elif normalized >= 45 and normalized < 135:
          return TileEdge.EAST
      elif normalized >= 135 and normalized < 225:
          return TileEdge.SOUTH
      else:
          return TileEdge.WEST
  ```

- [ ] **3.2: Implement get_edge_position()**
  ```gdscript
  func get_edge_world_position(tile_grid: Vector3i, edge: TileEdge, thickness: float) -> Vector3:
      # Returns world position for wall center on specified edge
      var tile_center = grid_to_world(tile_grid)
      var half_tile = grid_cell_size / 2.0

      # Position wall so INNER face sits flush with tile edge
      # Wall center = tile_edge_position + (thickness/2) outward
      var offset = half_tile + (thickness / 2.0)

      match edge:
          TileEdge.NORTH:
              return tile_center + Vector3(0, 0, offset)
          TileEdge.SOUTH:
              return tile_center + Vector3(0, 0, -offset)
          TileEdge.EAST:
              return tile_center + Vector3(offset, 0, 0)
          TileEdge.WEST:
              return tile_center + Vector3(-offset, 0, 0)

      return tile_center
  ```

- [ ] **3.3: Update Snapping Logic**
  - **Floors/Roofs**: Grid center snapping
    ```gdscript
    func snap_floor_to_grid(world_pos: Vector3) -> Vector3:
        var grid_pos = world_to_grid(world_pos)
        return grid_to_world(grid_pos)  # Returns tile center
    ```

  - **Walls/Door Frames**: Edge snapping
    ```gdscript
    func snap_wall_to_edge(world_pos: Vector3, rotation: int) -> Vector3:
        var nearest_tile = world_to_grid(world_pos)
        var edge = get_edge_from_rotation(rotation)
        var wall_data = building_data[current_building_id]
        var thickness = wall_data.get("wall_thickness", 0.1)
        return get_edge_world_position(nearest_tile, edge, thickness)
    ```

  - **Doors**: Inherit from nearest frame/wall
    ```gdscript
    func snap_door_to_frame(world_pos: Vector3) -> Dictionary:
        var nearest_frame = find_nearest_door_frame(world_pos, 3.0)
        if nearest_frame:
            return {
                "position": nearest_frame.global_position,
                "rotation": nearest_frame.rotation_degrees.y
            }
        else:
            # Fallback to wall-like edge snapping
            return {
                "position": snap_wall_to_edge(world_pos, building_rotation),
                "rotation": building_rotation
            }
    ```

- [ ] **3.4: Update Grid Position Key Generation**
  ```gdscript
  func grid_pos_to_key(grid_pos: Vector3i, building_id: String = "", edge: TileEdge = -1) -> String:
      # Edge-based buildings get edge-specific keys
      if building_id.contains("wall") or building_id.contains("door_frame"):
          return "%d,%d,%d-%s" % [grid_pos.x, grid_pos.y, grid_pos.z, TileEdge.keys()[edge]]
      # Floors/roofs use tile-center keys
      return "%d,%d,%d" % [grid_pos.x, grid_pos.y, grid_pos.z]
  ```

**Notes**:
- Inner face flush = tile edge position + (thickness/2) outward
- Four walls per tile possible (one per edge)
- Key must include edge direction to prevent conflicts

**Blockers**:

---

### 🔲 Phase 4: Preview & Placement Updates

**Goal**: Fix preview and placement to use grid system + geometry offsets

- [ ] **4.1: Update BuildingPreview3D.gd - Use Building Data**
  - Replace hardcoded sizes with `building_data[building_id]`
  - Get actual `world_size` and `geometry_offset`
  - Apply offset to mesh/CSG nodes for correct visual alignment

- [ ] **4.2: Update Preview Snapping**
  ```gdscript
  func update_position(world_pos: Vector3):
      var building_system = get_tree().get_first_node_in_group("building_system")
      var data = building_system.get_building_data(building_id)

      var grid_pos: Vector3
      if building_id.contains("wall") or building_id.contains("door_frame"):
          grid_pos = building_system.snap_wall_to_edge(world_pos, rotation_degrees.y)
      elif building_id == "door":
          var result = building_system.snap_door_to_frame(world_pos)
          grid_pos = result.position
          rotation_degrees.y = result.rotation
      else:
          grid_pos = building_system.snap_floor_to_grid(world_pos)

      # Apply ground detection
      var ground_y = find_ground_below(grid_pos)
      if ground_y != null:
          grid_pos.y = ground_y + calculate_height_offset(building_id, data)

      global_position = grid_pos
  ```

- [ ] **4.3: Update place_building() Function**
  ```gdscript
  func place_building(template_pos: Vector3):
      var data = building_data[current_building_id]

      # Calculate grid-snapped position
      var grid_pos: Vector3
      if current_building_id.contains("wall"):
          grid_pos = snap_wall_to_edge(template_pos, building_rotation)
      else:
          grid_pos = snap_floor_to_grid(template_pos)

      # Load prefab
      var placed_building = load_building_prefab(current_building_id)

      # Apply geometry offset so VISUAL appears at grid_pos
      # Root will be at grid_pos - geometry_offset
      var geometry_offset = data.get("geometry_offset", Vector3.ZERO)
      var rotated_offset = rotate_offset(geometry_offset, building_rotation)

      placed_building.global_position = grid_pos - rotated_offset
      placed_building.rotation_degrees = Vector3(0, building_rotation, 0)

      # Track in grid system
      var grid_coord = world_to_grid(grid_pos)
      var edge = get_edge_from_rotation(building_rotation) if current_building_id.contains("wall") else -1
      var key = grid_pos_to_key(grid_coord, current_building_id, edge)

      placed_buildings[key] = {
          "id": current_building_id,
          "grid_position": grid_coord,
          "world_position": grid_pos,
          "rotation": building_rotation,
          "edge": edge,
          "node": placed_building
      }
  ```

- [ ] **4.4: Helper Functions**
  ```gdscript
  func rotate_offset(offset: Vector3, rotation_deg: int) -> Vector3:
      # Rotate geometry offset for correct orientation
      var rotation_rad = deg_to_rad(rotation_deg)
      var transform = Transform3D()
      transform = transform.rotated(Vector3.UP, rotation_rad)
      return transform.basis * offset

  func calculate_height_offset(building_id: String, data: Dictionary) -> float:
      var mesh_height = data.world_size.y
      if building_id.contains("floor"):
          return 0.0  # Floor center at ground level
      elif building_id.contains("roof"):
          var wall_height = detect_wall_height_at_position(global_position)
          return wall_height - (mesh_height * 0.5) + 0.01  # 1cm overlap
      else:
          return mesh_height * 0.5  # Wall center at half height
  ```

**Notes**:
- Geometry offset must be rotated to match building rotation
- Root position ≠ Visual position (offset compensation)
- Grid tracking separate from visual rendering

**Blockers**:

---

### 🔲 Phase 5: Rotation Offset System (Unity Pattern)

**Goal**: Implement Unity's rotation offset calculation for multi-tile buildings

- [ ] **5.1: Add Rotation Offset Function**
  ```gdscript
  func get_rotation_offset(building_id: String, dir: int) -> Vector2i:
      # Returns grid offset based on rotation (Unity pattern)
      var data = building_data[building_id]
      var grid_size = data.get("grid_size", Vector2i(1, 1))
      var width = grid_size.x
      var height = grid_size.y

      # Normalize rotation to 0, 90, 180, 270
      var normalized = int(dir) % 360
      if normalized < 0: normalized += 360

      match normalized:
          0:   # Down/North
              return Vector2i(0, 0)
          90:  # Left/West
              return Vector2i(0, width)
          180: # Up/South
              return Vector2i(width, height)
          270: # Right/East
              return Vector2i(height, 0)
          _:
              return Vector2i(0, 0)
  ```

- [ ] **5.2: Update Placement Calculation**
  ```gdscript
  func calculate_building_world_position(grid_origin: Vector3i, building_id: String, rotation: int) -> Vector3:
      # Unity pattern: grid_world_pos + rotation_offset * cell_size
      var base_world = grid_to_world(grid_origin)
      var rotation_offset = get_rotation_offset(building_id, rotation)

      # Add rotation offset
      base_world.x += rotation_offset.x * grid_cell_size
      base_world.z += rotation_offset.y * grid_cell_size

      return base_world
  ```

- [ ] **5.3: Test Multi-Tile Buildings**
  - Create test building with grid_size(2, 1)
  - Place at all 4 rotations
  - Verify occupies correct grid cells
  - Check that rotation_offset aligns properly

**Notes**:
- Unity uses this for buildings larger than 1x1 grid
- SimpleSpace uses 1x1 tiles, but system should support any size
- Important for future expansion (2x1 workbenches, etc.)

**Blockers**:

---

### 🔲 Phase 6: Testing & Validation

**Goal**: Verify gap-free placement and add debug tools

- [ ] **6.1: Create Validation Functions**
  ```gdscript
  func validate_building_alignment(building_node: Node3D) -> Dictionary:
      var result = {
          "valid": true,
          "errors": []
      }

      # Get adjacent buildings
      var building_id = extract_building_id_from_name(building_node.name)
      var data = building_data.get(building_id, {})

      if building_id.contains("floor"):
          # Check all 4 adjacent floor tiles
          var adjacent = get_adjacent_floors(building_node.global_position)
          for adj in adjacent:
              var gap = calculate_gap_between_meshes(building_node, adj)
              if gap > 0.01:  # More than 1cm gap
                  result.valid = false
                  result.errors.append("Gap of %.2fcm with adjacent floor" % (gap * 100))

      elif building_id.contains("wall"):
          # Check floor below
          var floor_below = find_floor_at_position(building_node.global_position)
          if floor_below:
              var is_flush = check_wall_flush_with_floor_edge(building_node, floor_below)
              if not is_flush:
                  result.valid = false
                  result.errors.append("Wall not flush with floor edge")

      elif building_id.contains("roof"):
          # Check walls below
          var walls = find_walls_at_position(building_node.global_position)
          if walls.is_empty():
              result.valid = false
              result.errors.append("Roof has no wall support")
          else:
              for wall in walls:
                  var overlap = calculate_roof_wall_overlap(building_node, wall)
                  if overlap < 0.005 or overlap > 0.02:  # Not ~1cm overlap
                      result.valid = false
                      result.errors.append("Roof overlap with wall is %.2fcm (should be ~1cm)" % (overlap * 100))

      return result
  ```

- [ ] **6.2: Add Debug Visualization**
  ```gdscript
  var debug_visualization_enabled: bool = false
  var debug_grid_lines: ImmediateMesh = null
  var debug_edge_markers: Array = []

  func toggle_debug_visualization():
      debug_visualization_enabled = !debug_visualization_enabled
      if debug_visualization_enabled:
          draw_debug_grid()
          draw_edge_markers()
      else:
          clear_debug_visuals()

  func draw_debug_grid():
      # Draw grid lines at ground level
      # Show grid cell boundaries with thin white lines
      # Highlight tile centers with small spheres
      pass

  func draw_edge_markers():
      # For each placed wall, draw colored sphere at its edge position
      # North = Blue, South = Green, East = Red, West = Yellow
      pass
  ```

- [ ] **6.3: Test Suite**
  - **Floor Placement Test**
    - [ ] Place 2x2 grid of floors
    - [ ] Verify no gaps between tiles
    - [ ] Check all tiles at same Y height

  - **Wall Placement Test**
    - [ ] Place floor tile
    - [ ] Place wall on each of 4 edges
    - [ ] Verify walls sit flush with floor edges
    - [ ] Check walls don't overlap each other

  - **Roof Placement Test**
    - [ ] Build 2x2 floor + 4 walls enclosure
    - [ ] Place roof tiles
    - [ ] Verify roof sits on wall tops with ~1cm overlap
    - [ ] Check no gaps between roof tiles

  - **Door/Frame Test**
    - [ ] Place wall with door frame
    - [ ] Place door in frame
    - [ ] Verify door fills frame opening exactly

  - **Rotation Test**
    - [ ] Place each building type at 0°, 90°, 180°, 270°
    - [ ] Verify all rotations produce gap-free results
    - [ ] Check geometry doesn't flip/mirror incorrectly

- [ ] **6.4: Performance Check**
  - Test with 50+ buildings placed
  - Verify no frame drops during placement
  - Check grid lookup performance

**Notes**:
- Add debug key binding (F8?) to toggle visualization
- Validation should run automatically after each placement
- Consider adding "Validate All Buildings" button to UI

**Blockers**:

---

### 🔲 Phase 7: Documentation & Cleanup

**Goal**: Finalize documentation and clean up debug code

- [ ] **7.1: Update This Document**
  - Mark all phases complete
  - Document any workarounds or edge cases
  - Add "Lessons Learned" section

- [ ] **7.2: Code Documentation**
  - Add detailed comments to grid functions
  - Document geometry offset calculations
  - Explain edge vs. center snapping logic

- [ ] **7.3: Update CLAUDE.md**
  - Update BuildingSystem status to "Complete"
  - Note any breaking changes
  - Document new grid system for future developers

- [ ] **7.4: Clean Up**
  - Remove excessive debug prints
  - Keep validation functions but disable by default
  - Optimize grid lookup if needed

- [ ] **7.5: Create User Guide**
  - How to place buildings (floors → walls → door frames → roof)
  - Explain grid snapping behavior
  - Tips for building enclosed structures

**Notes**:

**Blockers**:

---

## 📊 Progress Tracking

### Current Status
- **Phase 0**: 2/4 complete (50%)
- **Phase 1**: 0/3 complete (0%)
- **Phase 2**: 0/4 complete (0%)
- **Phase 3**: 0/4 complete (0%)
- **Phase 4**: 0/4 complete (0%)
- **Phase 5**: 0/3 complete (0%)
- **Phase 6**: 0/4 complete (0%)
- **Phase 7**: 0/5 complete (0%)

**Overall**: 2/31 tasks complete (6.5%)

### Timeline
- **Phase 0-2**: Foundation (Est. 2-3 hours)
- **Phase 3-4**: Core implementation (Est. 3-4 hours)
- **Phase 5**: Rotation system (Est. 1 hour)
- **Phase 6**: Testing (Est. 2 hours)
- **Phase 7**: Documentation (Est. 1 hour)

**Total Estimate**: 9-11 hours

---

## 🔧 Technical Reference

### SimpleSpace Prefab Measurements

**Floors** (SM_Env_Floor_01):
- Grid size: 1x1
- World size: 5m × 5m × 0.1m (width × depth × height)
- Mesh local position: (-2.5, 0, -2.5)
- Geometry offset: (-2.5, 0, -2.5)

**Walls** (SM_Env_Wall_02):
- Grid size: 1x1 (occupies edge, not tile)
- World size: 5m × 5m × 0.1m (width × height × thickness)
- Mesh local position: (-2.5, 0, 0)
- Geometry offset: (-2.5, 0, 0)
- Thickness: 0.1m

**Roofs** (SM_Env_Ceiling_01):
- Grid size: 1x1
- World size: 5m × 5m × 0.1m (width × depth × height)
- Mesh local position: (-2.5, 0, -2.5)
- Geometry offset: (-2.5, 0, -2.5)

**Door Frames** (SM_Bld_Wall_Doorframe_01):
- Grid size: 1x1 (occupies edge)
- World size: 5m × 5m × 0.1m
- Opening: 1.2m wide × 2.4m tall
- Mesh local position: TBD (needs measurement)

### Key Formulas

**Grid to World**:
```
world_pos = grid_origin + (grid_pos * cell_size)
```

**World to Grid**:
```
grid_pos = round((world_pos - grid_origin) / cell_size)
```

**Edge Position**:
```
edge_world = tile_center + edge_direction * (cell_size/2 + thickness/2)
```

**Building Root Position** (with geometry offset):
```
root_pos = grid_world_pos - rotate(geometry_offset, rotation)
```

---

## 🐛 Known Issues & Workarounds

### After Phase 5 Implementation (2025-10-14)

**Implementation Status**: Phases 1-5 completed with 5 commits on `feature/building-grid-system` branch. Code review revealed critical issues that must be resolved before Phase 6 testing.

---

#### 🔴 Critical Issue #1: Dual Snapping Systems

**Problem**: Two parallel snapping systems exist and produce different results, causing position mismatches between preview and actual placement.

**Location**:
- `BuildingPreview3D.gd:398-443` uses new `snap_wall_to_edge()` (Phase 3)
- `BuildingSystem.gd:is_valid_building_position()` uses legacy `snap_to_tile_edge()`

**Technical Details**:
```gdscript
// BuildingPreview3D shows preview at:
grid_pos = building_system.snap_wall_to_edge(world_pos, rotation)
// = tile_center + (half_tile + thickness/2)
// Example: tile_center(0,0,0) + (2.5 + 0.05) = (0, 0, 2.55)

// But is_valid_building_position() checks collision at:
grid_pos = get_grid_snapped_position(pos, building_id, rotation)
// which calls snap_to_tile_edge() = tile_center + half_tile
// Example: tile_center(0,0,0) + 2.5 = (0, 0, 2.5)

// These are DIFFERENT positions! (off by thickness/2 = 0.05m)
```

**Impact**:
- Preview shows building at position A (e.g., 2.55m)
- Collision check validates position B (e.g., 2.5m)
- Actual placement happens at position B
- Result: Building doesn't appear where preview showed

**Root Cause**:
- `snap_to_tile_edge()` places walls AT the tile edge (inner and outer faces both wrong)
- `snap_wall_to_edge()` places walls so inner face is flush with tile edge (correct)
- Both functions are being called in different parts of the code

**Resolution Required**:
1. **Update `is_valid_building_position()`** to use Phase 3 snapping functions:
   ```gdscript
   # Replace this:
   var grid_pos = get_grid_snapped_position(pos, building_id, rotation)

   # With this:
   var grid_pos: Vector3
   if building_id.contains("wall") or building_id.contains("door_frame"):
       grid_pos = snap_wall_to_edge(pos, rotation, building_id)
   else:
       grid_pos = snap_floor_to_grid(pos)
   ```

2. **Update `place_building()`** to use same snapping:
   ```gdscript
   # Apply same logic as preview system
   if current_building_id.contains("wall"):
       grid_pos = snap_wall_to_edge(template_pos, building_rotation, current_building_id)
   else:
       grid_pos = snap_floor_to_grid(template_pos)
   ```

3. **Deprecate legacy functions**:
   - Mark `snap_to_tile_edge()` as deprecated
   - Mark `get_grid_snapped_position()` as deprecated
   - Add comments redirecting to Phase 3 functions

**Files to Modify**:
- `BuildingSystem.gd:is_valid_building_position()` (uses legacy snap)
- `BuildingSystem.gd:place_building()` (uses legacy snap)
- `BuildingSystem.gd:snap_to_tile_edge()` (mark deprecated)
- `BuildingSystem.gd:get_grid_snapped_position()` (mark deprecated)

---

#### 🔴 Critical Issue #2: Hardcoded Geometry Offsets Not Utilized

**Problem**: `place_building()` uses hardcoded geometry offsets instead of extracted data from MeshInspector, defeating the purpose of Phase 2.

**Location**: `BuildingSystem.gd:642-671`

**Current Code**:
```gdscript
if is_building_from_template:
    var local_visual_center = Vector3.ZERO

    # HARDCODED VALUES - ignoring building_data!
    if current_building_id in ["basic_floor", "basic_wall"]:
        local_visual_center = Vector3(-5, 0, 0)
    elif current_building_id == "basic_roof":
        local_visual_center = Vector3(-5, 0, -5)
    # ... more hardcoded cases
```

**What Should Happen**:
```gdscript
if is_building_from_template:
    # Use extracted geometry offset from building_data
    var data = building_data.get(current_building_id, {})
    var geometry_offset = data.get("geometry_offset", Vector3.ZERO)

    # Rotate offset to match building orientation
    var rotated_offset = rotate_offset(geometry_offset, building_rotation)

    # Position root so VISUAL appears at template_pos
    placed_building.global_position = template_pos - rotated_offset
```

**Impact**:
- Phase 2 lazy-loading system extracts correct offsets but they're never used
- New buildings added to the game must manually add hardcoded offsets
- Changes to GLB files require code updates instead of automatic detection
- The extracted `geometry_offset` field in `building_data` is completely ignored

**Root Cause**:
- Legacy placement code written before Phase 2 implementation
- Hardcoded values were temporary until geometry extraction was available
- Never replaced with actual extracted data after MeshInspector was integrated

**Resolution Required**:
1. **Replace entire hardcoded section** (lines 642-671):
   ```gdscript
   # OLD: Hardcoded offsets
   if current_building_id in ["basic_floor", "basic_wall"]:
       local_visual_center = Vector3(-5, 0, 0)

   # NEW: Use extracted geometry offset
   var data = building_data.get(current_building_id, {})
   var geometry_offset = data.get("geometry_offset", Vector3.ZERO)
   var rotated_offset = rotate_offset(geometry_offset, building_rotation)
   placed_building.global_position = template_pos - rotated_offset
   ```

2. **Ensure geometry offset is available**:
   - Phase 2 lazy-loading should have already extracted it
   - If not loaded yet, trigger `get_building_geometry(current_building_id)`

3. **Test with all building types**:
   - Verify floors appear at correct position
   - Verify walls appear at correct position
   - Verify roofs appear at correct position
   - Check rotations don't break positioning

**Files to Modify**:
- `BuildingSystem.gd:place_building()` lines 642-671 (remove hardcoded offsets)

---

#### 🟡 Medium Issue #3: Mixed Coordinate Systems

**Problem**: Legacy grid functions and new grid functions coexist, using different coordinate systems (Vector3 vs Vector2i).

**Location**: Various locations in `BuildingSystem.gd`

**Technical Details**:
- **Legacy system**: Uses `Vector3` for grid positions (3D world-like coordinates)
  - `snap_to_tile_edge()` returns `Vector3`
  - `get_grid_snapped_position()` returns `Vector3`
  - Stored in `placed_buildings` dictionary with Vector3 keys

- **New system**: Uses `Vector2i` for grid positions (true 2D grid coordinates)
  - `world_to_grid()` returns `Vector2i`
  - `grid_to_world()` takes `Vector2i`
  - `grid_objects` dictionary uses Vector2i-based string keys

**Impact**:
- Code is confusing - unclear which system to use
- Risk of mixing coordinate systems causing position errors
- Dictionary lookups might fail if keys are inconsistent
- Future developers won't know which functions to use

**Resolution Required**:
1. **Standardize on Vector2i for grid coordinates**:
   - Grid coordinates should always be `Vector2i(x, z)` (Y omitted for 2D grid)
   - World positions should always be `Vector3(x, y, z)`
   - Functions should never mix these types

2. **Update legacy functions**:
   ```gdscript
   # Mark as deprecated, redirect to new functions
   func snap_to_tile_edge(pos: Vector3, rotation: int) -> Vector3:
       push_warning("snap_to_tile_edge() is deprecated. Use snap_wall_to_edge() instead.")
       return snap_wall_to_edge(pos, rotation, current_building_id)

   func get_grid_snapped_position(pos: Vector3, building_id: String, rotation: int) -> Vector3:
       push_warning("get_grid_snapped_position() is deprecated. Use snap_floor_to_grid() or snap_wall_to_edge().")
       if building_id.contains("wall"):
           return snap_wall_to_edge(pos, rotation, building_id)
       else:
           return snap_floor_to_grid(pos)
   ```

3. **Document coordinate system rules**:
   - Add comments explaining Vector2i vs Vector3 usage
   - Document which functions use which coordinate system
   - Add type hints to all function signatures

**Files to Modify**:
- `BuildingSystem.gd` (add deprecation warnings to legacy functions)
- `BuildingSystem.gd` (add documentation comments)

---

#### Resolution Priority

**🔴 Must Fix Before Phase 6 Testing (BLOCKING)**:
1. Critical Issue #1 - Dual snapping systems (breaks placement accuracy)
2. Critical Issue #2 - Hardcoded geometry offsets (defeats Phase 2 purpose)
3. Critical Issue #4 - grid_objects dictionary never used (Phase 1 incomplete)
4. Critical Issue #5 - calculate_building_world_position() never called (Phase 5 incomplete)

**🟡 Should Fix During Phase 6 Implementation**:
5. Medium Issue #3 - Mixed coordinate systems (causes confusion)
6. Medium Issue #4 - grid_pos_to_key() type mismatch (Vector3 vs Vector2i)
7. Medium Issue #5 - Lazy-loading not triggered before use (race condition)
8. Medium Issue #6 - Mixed edge direction systems (String vs enum)

**Summary**:
- **5 Critical Issues** - Phases 1-5 have incomplete integration
- **4 Medium Issues** - Technical debt and consistency problems
- **Estimated Fix Time**: 3-4 hours for all critical issues

---

#### Original Issue Resolution Status

After Phase 5 implementation, reviewing against the original 4 issues from "Current Godot Issues":

**✅ Issue 4 (No True Grid) - FULLY RESOLVED**:
- Implemented `Vector2i` grid coordinates with `world_to_grid()` / `grid_to_world()`
- Grid tracking dictionary `grid_objects` with grid coordinate keys
- Edge-specific keys: `"x,y,z-NORTH"` format for walls
- Grid-based collision detection possible

**✅ Issue 3 (Wall Snapping) - RESOLVED**:
- `snap_wall_to_edge()` uses actual building thickness from `building_data`
- `get_edge_world_position()` calculates: `tile_edge + (thickness/2)` outward
- Inner face sits flush with tile edge as intended
- ⚠️ BUT: Not being used everywhere (see Critical Issue #1)

**⚠️ Issue 1 (Size Inconsistency) - MOSTLY RESOLVED**:
- Phase 2 MeshInspector extracts actual AABB dimensions from GLB files
- Lazy-loading architecture updates `building_data` with real world size
- Works correctly after first use of each building type
- ⚠️ BUT: Initial load still uses hardcoded sizes from JSON until GLB is inspected

**❌ Issue 2 (Geometry Offset) - EXTRACTED BUT NOT UTILIZED**:
- Phase 2 MeshInspector successfully extracts `geometry_offset` from GLB files
- Data is stored in `building_data[building_id].geometry_offset`
- ❌ BUT: `place_building()` still uses hardcoded offsets (see Critical Issue #2)
- This is a **regression** - we have the data but aren't using it!

---

#### 🔴 Critical Issue #4: grid_objects Dictionary Never Used

**Problem**: Phase 1 added `grid_objects` dictionary for Vector2i-based grid tracking, but the code still uses legacy `placed_buildings` dictionary throughout.

**Location**:
- `BuildingSystem.gd:66` - `var grid_objects: Dictionary = {}` (declared but never used)
- `BuildingSystem.gd:445` - `is_valid_building_position()` checks `placed_buildings`
- `BuildingSystem.gd:719` - `place_building()` stores in `placed_buildings`
- `BuildingSystem.gd:1292` - `demolish_building_direct()` removes from `placed_buildings`

**Technical Details**:
```gdscript
# Phase 1 added this new dictionary:
var grid_objects: Dictionary = {}  # Replaces placed_buildings with grid-based keys

# But all code still uses the old dictionary:
if pos_key in placed_buildings:  # Should use grid_objects!
    return false

placed_buildings[pos_key] = { ... }  # Should use grid_objects!
```

**Impact**:
- `grid_objects` was intended to use Vector2i-based keys for true grid tracking
- `placed_buildings` uses Vector3-based keys, maintaining the old world-space system
- This defeats the entire purpose of Phase 1's grid coordinate system
- Two tracking dictionaries exist but only the old one is used

**Root Cause**:
- Phase 1 created the new dictionary but didn't migrate the code to use it
- All placement/validation logic still references the old `placed_buildings`

**Resolution Required**:
1. **Find and replace all `placed_buildings` references**:
   ```gdscript
   # Replace everywhere:
   placed_buildings → grid_objects
   ```

2. **Update key generation to use Vector2i**:
   - `grid_pos_to_key()` should accept Vector2i instead of Vector3
   - Keys should be based on grid coordinates, not world positions

3. **Migrate existing data** (if buildings already placed):
   - Add migration function to convert `placed_buildings` → `grid_objects` on load

**Files to Modify**:
- `BuildingSystem.gd:445` - Update validation
- `BuildingSystem.gd:719-724` - Update placement tracking
- `BuildingSystem.gd:1292-1295` - Update demolition
- `BuildingSystem.gd:1000-1006` - Update `find_nearest_door_frame()`

---

#### 🔴 Critical Issue #5: calculate_building_world_position() Never Called

**Problem**: Phase 5 rotation offset function exists but is never used anywhere in the codebase.

**Location**: `BuildingSystem.gd:868-895` (function definition only)

**Technical Details**:
```gdscript
# Function exists and looks correct:
func calculate_building_world_position(grid_origin: Vector2i, building_id: String, rotation: int) -> Vector3:
    var base_world = grid_to_world(grid_origin.x, grid_origin.y, grid_size)
    # ... rotation offset calculation ...
    return base_world

# But it's NEVER CALLED anywhere!
# Search results: 0 references in BuildingSystem.gd
```

**Impact**:
- Multi-tile buildings (2x1, 3x2, etc.) won't have proper rotation offsets
- When a 2x1 building rotates 90°, it becomes 1x2 - without this function, it won't stay grid-aligned
- This is especially important for future buildings like workbenches (2x1), assemblers (3x2)

**Root Cause**:
- Phase 5 implemented the function but didn't integrate it into placement logic
- `place_building()` doesn't call it
- `is_valid_building_position()` doesn't call it

**Resolution Required**:
1. **Update `place_building()` to use rotation offsets**:
   ```gdscript
   # Instead of direct grid_to_world, use:
   var grid_origin = world_to_grid(pos)
   var grid_pos = calculate_building_world_position(grid_origin, current_building_id, building_rotation)
   ```

2. **Update validation to account for multi-tile occupancy**:
   - Check all grid cells occupied by a multi-tile building
   - Use rotation offset to determine which cells are occupied

3. **Test with multi-tile buildings**:
   - Workbench (2x1), Assembler (3x2), Food Processor (2x1), Water Purifier (2x1)

**Files to Modify**:
- `BuildingSystem.gd:place_building()` - Use for final position calculation
- `BuildingSystem.gd:is_valid_building_position()` - Check all occupied cells

---

#### 🟡 Medium Issue #4: grid_pos_to_key() Type Mismatch

**Problem**: `grid_pos_to_key()` expects `Vector3` but Phase 1 introduced `Vector2i` for grid coordinates.

**Location**: `BuildingSystem.gd:1078`

**Technical Details**:
```gdscript
# Current signature:
func grid_pos_to_key(grid_pos: Vector3, building_id: String = "", rotation: int = 0) -> String:
    return "%d,%d,%d-%s" % [grid_pos.x, grid_pos.y, grid_pos.z, edge_name]

# Should be:
func grid_pos_to_key(grid_pos: Vector2i, building_id: String = "", rotation: int = 0) -> String:
    return "%d,%d-%s" % [grid_pos.x, grid_pos.y, edge_name]
```

**Impact**:
- Inconsistent type usage throughout codebase
- Vector3 implies 3D world positions, but grid is 2D (x, z only)
- Y component is always 0 for ground-level buildings, wasting memory in keys

**Resolution Required**:
1. **Update function signature**:
   - Change parameter from `Vector3` to `Vector2i`
   - Update key format to use 2 integers instead of 3

2. **Update all callers**:
   - Convert Vector3 to Vector2i before calling: `world_to_grid(world_pos)`
   - Remove Y coordinate from key generation

**Files to Modify**:
- `BuildingSystem.gd:1078` - Update function signature
- `BuildingSystem.gd:442` - Update caller in `is_valid_building_position()`
- `BuildingSystem.gd:718` - Update caller in `place_building()`

---

#### 🟡 Medium Issue #5: Lazy-Loading Not Triggered Before Validation/Placement

**Problem**: `get_building_geometry()` is only called in `start_building_mode()`, but not before validation or placement operations.

**Location**:
- `BuildingSystem.gd:286` - Only call to `get_building_geometry()`
- `BuildingSystem.gd:423` - `is_valid_building_position()` doesn't trigger lazy-load
- `BuildingSystem.gd:529` - `place_building()` doesn't trigger lazy-load

**Technical Details**:
If a building is placed without preview (e.g., from template construction), the geometry data might not be loaded yet:

```gdscript
# Template construction path:
func _on_template_construction_completed(template):
    # ...
    place_building(template_pos)  # Geometry might not be loaded!

# place_building uses:
var building_info = building_data[current_building_id]
var geometry_offset = building_info.get("geometry_offset", Vector3.ZERO)
# If lazy-load didn't run, geometry_offset will be Vector3.ZERO (wrong!)
```

**Impact**:
- Buildings placed from templates might use wrong geometry offsets
- Buildings placed without opening build menu first would fail
- Race condition: geometry data availability depends on whether preview was created

**Resolution Required**:
1. **Add lazy-load trigger at start of critical functions**:
   ```gdscript
   func is_valid_building_position(pos: Vector3, building_id: String = "", rotation: int = -1) -> bool:
       var check_building_id = building_id if building_id != "" else current_building_id

       # Ensure geometry is loaded
       get_building_geometry(check_building_id)

       # ... rest of function
   ```

2. **Same for `place_building()`**:
   ```gdscript
   func place_building(pos: Vector3):
       # Ensure geometry is loaded before using geometry_offset
       get_building_geometry(current_building_id)

       var building_info = building_data[current_building_id]
       # Now safe to use geometry_offset
   ```

**Files to Modify**:
- `BuildingSystem.gd:is_valid_building_position()` - Add lazy-load trigger
- `BuildingSystem.gd:place_building()` - Add lazy-load trigger

---

#### 🟡 Medium Issue #6: Mixed Edge Direction Systems

**Problem**: Two parallel systems for edge directions - TileEdge enum (new) and String directions (old).

**Location**:
- `BuildingSystem.gd:58-63` - `TileEdge enum` (NORTH, EAST, SOUTH, WEST)
- `BuildingSystem.gd:1094-1107` - `get_edge_direction_from_rotation()` returns String ("N", "E", "S", "W")
- `BuildingSystem.gd:904` - `get_edge_from_rotation()` returns `TileEdge` enum

**Technical Details**:
```gdscript
# New Phase 3 system:
enum TileEdge {
    NORTH = 0,
    EAST = 1,
    SOUTH = 2,
    WEST = 3
}
func get_edge_from_rotation(rotation_deg: int) -> TileEdge

# Old legacy system:
func get_edge_direction_from_rotation(rotation: int) -> String:
    return "N"  # or "E", "S", "W"
```

**Impact**:
- Confusing which function to use
- String-based system is error-prone (typos, case sensitivity)
- Enum system is type-safe and consistent with Phase 3 design
- Legacy code might still use strings while new code uses enums

**Resolution Required**:
1. **Deprecate string-based function**:
   ```gdscript
   func get_edge_direction_from_rotation(rotation: int) -> String:
       push_warning("get_edge_direction_from_rotation() is deprecated. Use get_edge_from_rotation() instead.")
       # Convert enum to string for backward compatibility
       var edge = get_edge_from_rotation(rotation)
       match edge:
           TileEdge.NORTH: return "N"
           TileEdge.EAST: return "E"
           TileEdge.SOUTH: return "S"
           TileEdge.WEST: return "W"
       return "N"
   ```

2. **Update all callers to use enum**:
   - Search for `get_edge_direction_from_rotation` calls
   - Replace with `get_edge_from_rotation`

**Files to Modify**:
- `BuildingSystem.gd:1094` - Add deprecation warning
- `BuildingSystem.gd:1054-1076` - Update `snap_to_tile_edge()` to use enum if still needed

---

## 💡 Lessons Learned

*To be filled in after completion*

---

## 🎯 Success Criteria

- [x] Tracking document created
- [ ] All floors align with no visible gaps (< 1mm)
- [ ] Walls sit flush on tile edges, inner face at edge line
- [ ] Roofs overlap walls by exactly 1cm, no z-fighting
- [ ] Door frames create perfect openings for doors
- [ ] All 4 rotations work correctly for every building type
- [ ] System supports any grid size (1m, 5m, 10m, etc.)
- [ ] No performance degradation with 50+ buildings
- [ ] Code is well-documented and maintainable

---

**Last Updated**: 2025-10-14 22:30
**Next Review**: After Phase 2 completion
