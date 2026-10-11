"""Regenerate only progress state-row DTO declarations from reviewed core DDL.

Commands, views, and ports remain hand-written in contract_dtos.gd.
Run tests and the Godot parser after every schema change.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SQL = ROOT / "code/database/progress/001_core.sql"
GD = ROOT / "code/contracts/contract_dtos.gd"
ENUM_FIELDS = {
    ("player_state", "camera_mode"): ("CameraMode", "FOLLOW"),
    ("ship_state", "status"): ("ShipStatus", "FLYING"),
    ("container_state", "kind"): ("ContainerKind", "STATION"),
    ("container_state", "slot_type"): ("SlotType", "WEAPON"),
    ("item_instance_state", "origin_kind"): ("ItemOrigin", "PURCHASE"),
    ("inventory_stack_state", "origin_kind"): ("StackOrigin", "NORMAL"),
    ("loan_state", "status"): ("LoanStatus", "AVAILABLE"),
    ("npc_state", "behavior_phase"): ("NpcPhase", "IDLE"),
    ("discovery_state", "kind"): ("DiscoveryKind", "SIGNAL"),
    ("transfer_state", "endpoint"): ("TransferEndpoint", "ORIGIN"),
}


def split_columns(body):
    result, start, depth, quoted = [], 0, 0, False
    for index, char in enumerate(body):
        if char == "'":
            quoted = not quoted
        if not quoted:
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
            elif char == "," and depth == 0:
                result.append(body[start:index].strip())
                start = index + 1
    result.append(body[start:].strip())
    return result


def class_name(table):
    return "".join(part.capitalize() for part in table.split("_")) + "Dto"


def main():
    tables = dict(re.findall(r"CREATE TABLE (\w+) \((.*?)\) STRICT;", SQL.read_text(), re.S))
    states = [table for table in tables if table.endswith("_state")]
    generated = {class_name(table) for table in states}
    existing = set(re.findall(r"class (\w+StateDto) extends RefCounted:", GD.read_text(encoding="utf-8")))
    if existing - generated:
        raise ValueError("Core-only generator cannot replace expanded state DTOs; append the reviewed migration's declarations instead")
    lines = []
    for table in states:
        lines += [f"## 对应 progress.{table}；公共复合键由 WorldSnapshot.meta 注入。", f"class {class_name(table)} extends RefCounted:"]
        for column in split_columns(tables[table]):
            match = re.match(r"(\w+)\s+(TEXT|INTEGER|REAL)\b(.*)", column, re.S)
            if not match:
                continue
            name, kind, rest = match.groups()
            if name in ("snapshot_id", "world_id", "content_snapshot_id"):
                continue
            if "NOT NULL" not in rest and "PRIMARY KEY" not in rest:
                lines.append(f"\tvar has_{name}: bool = false")
            if (table, name) in ENUM_FIELDS:
                enum, default = ENUM_FIELDS[(table, name)]
                dtype, default = f"Types.{enum}", f"Types.{enum}.{default}"
            elif kind == "INTEGER" and re.search(r"CHECK\s*\(\s*" + re.escape(name) + r"\s+IN\s*\(\s*0\s*,\s*1\s*\)", rest):
                dtype, default = "bool", "false"
            else:
                dtype, default = {"TEXT": ("String", '""'), "INTEGER": ("int", "0"), "REAL": ("float", "0.0")}[kind]
            if name == "quat_w":
                default = "1.0"
            lines.append(f"\tvar {name}: {dtype} = {default}")
        lines.append("")
    existing = GD.read_text()
    head = existing.split("## 对应 progress.player_state", 1)[0]
    view = "class WorldViewDto" + existing.split("class WorldViewDto", 1)[1]
    between = existing.split("class WorldSnapshotDto", 1)[1].split("## 表现派生值不是另一份定义", 1)[1]
    metrics = "## 表现派生值不是另一份定义" + between.split("class WorldViewDto", 1)[0]
    snapshot = ["## 完整世界快照：所有已初始化星区状态都在数组中，不限当前已加载星区。", "class WorldSnapshotDto extends RefCounted:", "\tvar meta: SnapshotMetaDto = SnapshotMetaDto.new()", "\tvar content: ContentRefDto = ContentRefDto.new()"]
    snapshot += [f"\tvar {table}_rows: Array[{class_name(table)}] = []" for table in states]
    GD.write_text(head + "\n".join(lines + snapshot) + "\n\n" + metrics + view)
    print(f"Synced {len(states)} progress state DTOs; parse/test verification still required")


if __name__ == "__main__":
    main()
