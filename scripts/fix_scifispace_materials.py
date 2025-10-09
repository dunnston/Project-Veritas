#!/usr/bin/env python3
"""
Script to automatically fix SciFiSpace prefab materials
by applying textures from the MaterialList reference document
"""

import os
import re
from pathlib import Path
from typing import Dict, List, Tuple

# Configuration
MATERIAL_LIST_PATH = "assets/enviroment/scifispace/MaterialList_PolygonSciFiSpace.txt"
PREFABS_DIR = "assets/enviroment/scifispace/Prefabs"
TEXTURES_DIR = "assets/enviroment/scifispace/Textures"

def parse_material_list(file_path: str) -> Dict[str, List[Tuple[str, str]]]:
    """
    Parse the MaterialList to extract prefab -> mesh -> texture mappings
    Returns: Dict[prefab_name] = [(mesh_name, texture_name), ...]
    """
    prefab_map = {}
    current_prefab = None
    current_mesh = None

    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()

            # Match prefab name
            prefab_match = re.match(r'Prefab Name: (.+)', line)
            if prefab_match:
                current_prefab = prefab_match.group(1)
                if current_prefab not in prefab_map:
                    prefab_map[current_prefab] = []
                continue

            # Match mesh name
            mesh_match = re.match(r'Mesh Name: (.+)', line)
            if mesh_match:
                current_mesh = mesh_match.group(1)
                continue

            # Match texture slot
            slot_match = re.match(r'Slot: .+\((.+)\)', line)
            if slot_match and current_prefab and current_mesh:
                texture_name = slot_match.group(1)
                prefab_map[current_prefab].append((current_mesh, texture_name))

    return prefab_map

def find_texture_path(texture_name: str) -> str:
    """Find the texture file path in the Textures directory"""
    # Standard textures are in the main Textures folder
    texture_path = f"res://{TEXTURES_DIR}/{texture_name}.png"

    # Check for alternate textures in Alts subfolder
    alts_path = f"res://{TEXTURES_DIR}/Alts/{texture_name}.png"

    # Check for FX textures in FX_Textures subfolder
    fx_path = f"res://{TEXTURES_DIR}/FX_Textures/{texture_name}.png"

    # Return the most likely path (you can add more logic here)
    return texture_path

def update_scene_material(scene_path: str, prefab_name: str, texture_mappings: List[Tuple[str, str]]):
    """
    Update a .tscn file to fix material textures
    """
    if not texture_mappings:
        print(f"  ⚠️  No texture mappings found for {prefab_name}")
        return

    # For now, we'll use the first texture mapping
    # (Some prefabs may have multiple meshes, but most have one)
    mesh_name, texture_name = texture_mappings[0]
    texture_path = find_texture_path(texture_name)

    print(f"  📝 Processing {prefab_name}")
    print(f"     Texture: {texture_name}")

    # Read the scene file
    with open(scene_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find StandardMaterial3D sections
    # Look for the material definition and update the albedo texture
    pattern = r'(\[sub_resource type="StandardMaterial3D" id="[^"]+"\])'

    def replace_material(match):
        material_block = match.group(1)
        # Check if there's already an albedo_texture line following this
        # If not, we'll add one after the material declaration
        return material_block

    # For now, let's do a simpler approach:
    # 1. Check if the material already has albedo_texture
    # 2. If not, add it
    # 3. If yes, update it

    if 'albedo_texture' not in content:
        # Need to add albedo_texture to the material
        # Find the StandardMaterial3D resource and add the texture after resource_name
        pattern = r'(\[sub_resource type="StandardMaterial3D" id="([^"]+)"\]\s*(?:resource_name = "[^"]*"\s*)?)'

        def add_texture(match):
            existing = match.group(1)
            # Add albedo_texture line
            return existing + f'albedo_texture = ExtResource("{texture_name}")\n'

        # We also need to add the texture as an ExtResource
        # Find the highest ext_resource id
        ext_resources = re.findall(r'\[ext_resource[^\]]+id="(\d+)_[^"]+"\]', content)
        if ext_resources:
            next_id = max([int(x) for x in ext_resources]) + 1
        else:
            next_id = 1

        # Add the texture as an ExtResource at the top of the file
        # Find where to insert it (after the last ext_resource or after gd_scene line)
        last_ext_resource_match = list(re.finditer(r'\[ext_resource[^\]]+\]', content))
        if last_ext_resource_match:
            insert_pos = last_ext_resource_match[-1].end()
            # Add a newline and the new ext_resource
            new_ext_resource = f'\n[ext_resource type="Texture2D" path="{texture_path}" id="{next_id}_texture"]'
            content = content[:insert_pos] + new_ext_resource + content[insert_pos:]

        # Now add albedo_texture to the material
        content = re.sub(pattern, add_texture, content)

    # Write back the scene file
    with open(scene_path, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"  ✅ Updated {prefab_name}")

def main():
    print("🔧 SciFiSpace Material Fixer")
    print("=" * 50)

    # Parse the material list
    print("\n📖 Parsing MaterialList...")
    material_map = parse_material_list(MATERIAL_LIST_PATH)
    print(f"   Found {len(material_map)} prefabs")

    # Get all prefab scene files
    prefab_files = list(Path(PREFABS_DIR).glob("*.tscn"))
    print(f"\n🔍 Found {len(prefab_files)} scene files")

    # Process each prefab
    processed = 0
    skipped = 0

    for prefab_file in prefab_files:
        prefab_name = prefab_file.stem  # Filename without extension

        if prefab_name in material_map:
            texture_mappings = material_map[prefab_name]
            update_scene_material(str(prefab_file), prefab_name, texture_mappings)
            processed += 1
        else:
            print(f"  ⏭️  Skipping {prefab_name} (not in MaterialList)")
            skipped += 1

    print("\n" + "=" * 50)
    print(f"✨ Complete!")
    print(f"   Processed: {processed}")
    print(f"   Skipped: {skipped}")
    print(f"   Total: {len(prefab_files)}")

if __name__ == "__main__":
    main()
