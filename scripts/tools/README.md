# Tool Scripts

## convert_prefabs_to_scenes.gd

Converts all prefab files from `assets/enviroment/desert/Prefabs/` into inherited scenes in `scenes/environment/desert/`.

### How to Run:

1. Open Godot Editor
2. Open the script: `scripts/tools/convert_prefabs_to_scenes.gd`
3. Click **File > Run** in the script editor (or press Ctrl+Shift+X)
4. Check the Output panel for conversion results

### What it does:

- Creates `scenes/environment/desert/` directory if it doesn't exist
- Copies all 177 prefab scenes from the assets folder
- Instances each prefab and repacks it as a new scene
- Saves the new scenes in the organized scenes directory
- Skips files that already exist (won't overwrite)
- Prints progress for each file converted

### Output:

```
=== Starting Prefab to Scene Conversion ===
Found 177 prefab files to convert
  Converted: SM_Env_Cactus_01.tscn
  Converted: SM_Env_Cactus_02.tscn
  Converted: SM_Env_Rock_01.tscn
  ...
=== Conversion Complete ===
Converted: 177 scenes
Skipped: 0 scenes (already exist)
Target directory: res://scenes/environment/desert/
```

### After Running:

All desert environment prefabs will be available in `scenes/environment/desert/` for easy drag-and-drop into your scenes.
