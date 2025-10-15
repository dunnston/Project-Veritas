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

*To be filled in during implementation*

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
