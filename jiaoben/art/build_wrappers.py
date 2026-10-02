"""固定模型几何与挂点生成；读取槽定义只作完整性核对，不从DB定义碰撞尺寸。"""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "code/assets"
VERSION = "art-full-v1"
SLOTS = {
    "shuttle_swift": (1, 0, 2, 1), "frigate_lantern": (1, 1, 3, 1),
    "frigate_kestrel": (2, 0, 3, 2), "miner_anvil": (1, 2, 3, 2),
    "destroyer_raptor": (3, 0, 4, 2), "cruiser_horizon": (3, 2, 5, 3),
    "battleship_bastion": (6, 1, 6, 4), "transport_caravan": (1, 1, 4, 3),
    "support_weaver": (2, 3, 5, 3),
    "enemy_silent": (2, 0, 1, 1),
}

def v3(values):
    return "Vector3(" + ", ".join(f"{v:.6g}" for v in values) + ")"

def old_markers(ship_id):
    text = (ASSETS / "placeholders" / f"{ship_id}.tscn").read_text()
    result = {}
    for block in re.split(r"\n(?=\[node)", text):
        match = re.match(r'\[node name="([^"]+)" type="Marker3D" parent="([^"]+)"\]', block)
        position = re.search(r"position = Vector3\(([^)]+)\)", block)
        if match and position:
            result[(match[2], match[1])] = [float(v) for v in position[1].split(",")]
    return result

def main():
    geometry_path = ASSETS / "models/geometry.json"
    geometry = json.loads(geometry_path.read_text())
    directory = ASSETS / "ships"
    directory.mkdir(exist_ok=True)
    for ship_id, slots in SLOTS.items():
        g = geometry[ship_id]
        width, height, length = g["collision_box_m"]
        old = old_markers(ship_id) if (ASSETS / "placeholders" / f"{ship_id}.tscn").exists() else {}
        markers = {}
        for slot_type, count in zip(("weapon", "work", "utility", "structure"), slots):
            for index in range(count):
                x = (index - (count - 1) / 2) * width / max(count, 2) * .72
                y = {"weapon": height * .22, "work": -height * .15,
                     "utility": height * .30, "structure": -height * .24}[slot_type]
                z = {"weapon": -length * .39, "work": -length * .28,
                     "utility": length * .09, "structure": length * .15}[slot_type]
                name = f"{slot_type}_{index}"
                markers[name] = old.get(("Hardpoints", name), [x, y, z])
        camera = old.get((".", "CameraTarget"), [0, height * .3, 0])
        front = old.get((".", "FrontCamera"), [0, height * .3, -length * .56])
        lines = [
            '[gd_scene load_steps=3 format=3]', '',
            f'[ext_resource type="PackedScene" path="res://assets/models/ships/{ship_id}.glb" id="1_model"]', '',
            '[sub_resource type="BoxShape3D" id="ShipCollision"]',
            f'size = {v3([width, height, length])}', '',
            '[node name="ShipBody" type="CharacterBody3D"]',
            'motion_mode = 1', 'collision_layer = 2', 'collision_mask = 3',
            f'metadata/ship_def_id = "{ship_id}"',
            f'metadata/asset_id = "asset_ship_{ship_id}"',
            f'metadata/asset_version = "{VERSION}"', '',
            '[node name="CollisionShape3D" type="CollisionShape3D" parent="."]',
            'shape = SubResource("ShipCollision")', '',
            '[node name="VisualRoot" type="Node3D" parent="."]', '',
            '[node name="Model" parent="VisualRoot" instance=ExtResource("1_model")]', '',
            '[node name="Hardpoints" type="Node3D" parent="."]', '',
        ]
        for name, position in markers.items():
            slot_type, index = name.rsplit("_", 1)
            lines += [f'[node name="{name}" type="Marker3D" parent="Hardpoints"]',
                      f'position = {v3(position)}', f'metadata/slot_type = "{slot_type}"',
                      f'metadata/slot_index = {index}', '']
            if slot_type == "weapon":
                lines += [f'[node name="muzzle" type="Marker3D" parent="Hardpoints/{name}"]', '']
        lines += ['[node name="FXAnchors" type="Node3D" parent="."]', '']
        for name, sign in (("engine_left", -1), ("engine_right", 1)):
            position = old.get(("FXAnchors", name), [sign * width * .18, 0, length * .46])
            lines += [f'[node name="{name}" type="Marker3D" parent="FXAnchors"]',
                      f'position = {v3(position)}', 'rotation = Vector3(0, 3.141592653589793, 0)', '']
        for name, position in (("CameraTarget", camera), ("FrontCamera", front), ("InteractionAnchor", [0, 0, 0])):
            lines += [f'[node name="{name}" type="Marker3D" parent="."]', f'position = {v3(position)}', '']
        (directory / f"{ship_id}.tscn").write_text("\n".join(lines))
        g.update({"asset_version": VERSION, "wrapper_path": f"res://assets/ships/{ship_id}.tscn",
                  "hardpoints": markers, "camera_target_m": camera, "front_camera_m": front})
    geometry_path.write_text(json.dumps(geometry, indent=2, ensure_ascii=False) + "\n")
    # 星区场景只提供背景入口；站/门/矿坐标一律由catalog的anchor_defs配置。
    sectors = ("anchor", "echo", "mirror", "forge", "iron", "helios", "drift", "mist", "rift", "silent")
    sector_dir = ASSETS / "sectors"
    sector_dir.mkdir(exist_ok=True)
    for sector in sectors:
        (sector_dir / f"sector_{sector}.tscn").write_text(
            '[gd_scene format=3]\n\n[node name="SectorVisualRoot" type="Node3D"]\n'
            f'metadata/asset_id = "scene_sector_{sector}"\nmetadata/sector_id = "sector_{sector}"\n'
            f'metadata/asset_version = "{VERSION}"\n')
    print("ART_WRAPPERS_COMPLETE", len(SLOTS), "ships", len(sectors), "sector roots")

if __name__ == "__main__":
    main()
