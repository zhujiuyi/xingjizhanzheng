"""Author six AU structures and eighteen variants as an additive SQL extension."""
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "code/data/catalog_resource_v10.db"


def literal(value):
    if value is None:
        return "NULL"
    if isinstance(value, str):
        return "'" + value.replace("'", "''") + "'"
    return repr(value)


def main():
    db = sqlite3.connect(BASELINE.as_uri() + "?mode=ro", uri=True)
    db.row_factory = sqlite3.Row
    assert db.execute("SELECT content_hash FROM catalog_meta").fetchone()[0] == "343a339385e647658e747f8c0cb4da1ee042a4f2a33af594e2f7bac1e9ae1854"
    sql = ["-- Authored exploration extension; all earlier definition rows remain unchanged."]

    def emit(table, values):
        sql.append("INSERT INTO " + table + " (" + ",".join(values) + ") VALUES (" + ",".join(literal(v) for v in values.values()) + ");")

    def clone(table, where):
        return dict(db.execute("SELECT * FROM " + table + " WHERE " + where).fetchone())

    def anchor(id_, sector, site, pivot, offset, kind="signal", radius=800.0):
        emit("anchor_defs", {"anchor_id": id_, "sector_id": sector, "anchor_kind": kind,
                            "x_m": float(pivot[0] + offset[0]), "y_m": float(pivot[1] + offset[1]), "z_m": float(pivot[2] + offset[2]),
                            "yaw_rad": 0.0, "interaction_radius_m": radius, "safe_radius_m": 0.0})
        emit("anchor_site_defs", {"anchor_id": id_, "site_id": site})

    emit("exploration_balance_defs", {"singleton": 1, "hazard_period_s": 32.0, "hazard_warning_s": 8.0, "hazard_active_s": 5.0,
                                      "hazard_radius_m": 1400.0, "solar_damage_hp_s": 12.0, "em_scan_multiplier": 0.55,
                                      "em_shield_multiplier": 0.5, "stabilized_multiplier": 0.25,
                                      "escort_follow_m": 2500.0, "extraction_radius_m": 350.0, "escort_departure_m": 3000.0, "transport_initial_hull_ratio": 0.35})
    archetype = clone("npc_archetype_defs", "archetype_id='npc_scout_light'")
    archetype.update(archetype_id="exp_transport", display_name="受损民用运输舰", base_shield=160, base_armor=300, base_hull=900,
                     base_raw_dps=1.0, speed_mps=120.0, range_m=550.0, base_reward_credit=0)
    emit("npc_archetype_defs", archetype)
    for row in db.execute("SELECT * FROM npc_resistances WHERE archetype_id='npc_scout_light'"):
        values = dict(row); values["archetype_id"] = "exp_transport"; emit("npc_resistances", values)
    behavior = clone("npc_behavior_defs", "archetype_id='npc_scout_light'")
    behavior.update(behavior_id="exp_transport_behavior", archetype_id="exp_transport", acceleration_mps2=25.0, turn_rad_s=1.0)
    emit("npc_behavior_defs", behavior)
    events = [
        ("exp_echo_rescue", "碎片走廊的求救讯号", "rescue", "sector_echo", "fragments", "救生信号穿过碎片带传来，附近有活动推进痕迹。"),
        ("exp_echo_mineral", "失联矿带的反射回波", "mineral", "sector_echo", "fragments", "临时矿带正在散逸，外围较安全，核心有更稀缺的声纹硅矿。"),
        ("exp_mirror_relic", "镜相档案的干扰载波", "relic", "sector_mirror", "em", "电磁场遮蔽了遗迹档案；可先稳定风险源，或带着风险深入。"),
        ("exp_mirror_rescue", "遭袭运输队的应答灯", "rescue", "sector_mirror", "solar", "受损运输舰仍在应答，恒星活动与截击者正在逼近。"),
        ("exp_forge_relic", "恒星观测站的残存记录", "relic", "sector_forge", "solar", "观测站周期性暴露在恒星喷流中，预警后可离开危险范围。"),
        ("exp_forge_mineral", "日冕矿脉的短暂窗口", "mineral", "sector_forge", "solar", "外围铁硅矿可稳定回收，核心曜核晶矿需要高级采集设备并承受暴露风险。"),
    ]
    au = 149597870700.0
    for index, (event, title, kind, sector, environment, clue) in enumerate(events):
        station = dict(db.execute("SELECT * FROM station_defs WHERE sector_id=? ORDER BY station_id LIMIT 1", (sector,)).fetchone())
        home = dict(db.execute("SELECT s.* FROM site_defs s JOIN anchor_site_defs a USING(site_id) WHERE a.anchor_id=?", (station["station_anchor_id"],)).fetchone())
        returning = station["station_id"]
        if not db.execute("SELECT 1 FROM station_service_defs WHERE station_id=? AND service_id='manufacture'", (returning,)).fetchone():
            returning = "station_anchor_port"
        # Each AU site has its own local coordinate namespace; do not enlarge
        # encoded legacy sector bounds to manufacture strategic separation.
        pivot = (0.0, 0.0, 0.0)
        site = event + "_site"
        entry, exit_ = event + "_entry", event + "_exit"
        emit("site_defs", {"site_id": site, "sector_id": sector, "display_name": title, "site_kind": "signal",
                           "x_m": home["x_m"] + au * (1.2 + index * 0.45), "y_m": home["y_m"] + au * 0.015 * (index + 1),
                           "z_m": home["z_m"] - au * (0.7 + index * 0.2), "pivot_x_m": pivot[0], "pivot_y_m": pivot[1], "pivot_z_m": pivot[2], "local_radius_m": 150000.0})
        anchor(entry, sector, site, pivot, (0, 0, 0))
        anchor(exit_, sector, site, pivot, (5200 + index * 200, 150, 800), "signal", 350.0)
        emit("exploration_event_defs", {"event_id": event, "display_name": title, "event_kind": kind, "sector_id": sector,
                                        "entry_anchor_id": entry, "exit_anchor_id": exit_, "station_id": returning,
                                        "required_unlock_id": "unlock_open_routes", "environment_kind": environment,
                                        "clue_text": clue, "cooldown_s": 1200.0, "operation_range_m": 800.0})
        for variant in range(1, 4):
            emit("exploration_variant_defs", {"variant_id": event + "_v" + str(variant), "event_id": event,
                "variant_index": variant, "display_name": ("短暂窗口", "截击压力", "复杂回声")[variant - 1],
                "duration_s": float((240, 300, 360)[variant - 1]), "enemy_count": variant,
                "repair_units": 2 + variant, "recovery_item_id": "material_structural_stock", "recovery_units": 5 + variant * 3,
                "full_credit": 5000 + variant * 1500, "partial_credit": 1500 + variant * 500,
                "insight_units": 6 + variant * 2, "reputation_units": 30 + variant * 10,
                "survey_duration_s": 12.0 + variant * 2, "work_duration_s": 10.0 + variant * 2,
                "relic_layers": 3, "mineral_quota": 60, "mineral_units": 300 + variant * 150})
        npc = clone("npc_defs", "npc_id='npc_scout_light_l1'")
        npc.update(npc_id=event + "_transport", archetype_id="exp_transport", risk_zone_id=db.execute("SELECT risk_zone_id FROM sector_defs WHERE sector_id=?", (sector,)).fetchone()[0])
        if kind == "rescue": emit("npc_defs", npc)
        enemy = clone("npc_defs", "npc_id='npc_scout_light_l1'")
        enemy.update(npc_id=event + "_raider", risk_zone_id=npc["risk_zone_id"], level=db.execute("SELECT npc_level_min FROM risk_zone_defs WHERE risk_zone_id=?", (npc["risk_zone_id"],)).fetchone()[0])
        emit("npc_defs", enemy)
        roles = [("enemy", slot) for slot in range(3)] + ([("escort", 0)] if kind == "rescue" else [])
        for role, slot in roles:
            spawn = event + "_" + role + "_" + str(slot)
            point = spawn + "_anchor"
            offset = (1800.0 + slot * 220, 60.0 * (slot - 1), -800.0 + slot * 500) if role == "enemy" else (150.0, 0.0, -100.0)
            anchor(point, sector, site, pivot, offset, "npc_spawn", 80.0)
            emit("npc_spawn_defs", {"spawn_id": spawn, "npc_id": enemy["npc_id"] if role == "enemy" else npc["npc_id"],
                "sector_id": sector, "anchor_id": point, "behavior_id": "behavior_scout" if role == "enemy" else "exp_transport_behavior",
                "occurrence_mode": "mission_scoped", "required_unlock_id": "unlock_open_routes", "respawn_s": None, "bounty_enabled": 0, "loot_enabled": 0})
            patrol = spawn + "_patrol"
            anchor(patrol, sector, site, pivot, offset, "patrol", 80.0)
            emit("npc_patrol_points", {"spawn_id": spawn, "point_index": 0, "anchor_id": patrol})
            emit("exploration_actor_defs", {"event_id": event, "actor_role": role, "slot_index": slot, "spawn_id": spawn, "hull_id": "miner_anvil" if role == "escort" else None})
        if environment == "fragments":
            for obstacle, offset in enumerate(((500, 50, 250), (950, -80, -280), (1400, 120, 450), (2600, 0, -350))):
                point = event + "_debris_" + str(obstacle)
                anchor(point, sector, site, pivot, offset, "resource", 80.0)
                emit("exploration_obstacle_defs", {"obstacle_id": point, "event_id": event, "anchor_id": point, "radius_m": 90.0 + obstacle * 15.0})
        if kind == "mineral":
            for choice, item, offset, bp in (("safe", "ore_ferrosilicate", (2100, 0, 700), 10000),
                                            ("rich", "ore_echo_silica" if sector == "sector_echo" else "ore_solar_core", (350, 0, 100), 12000)):
                node = event + "_" + choice
                point = node + "_anchor"
                anchor(point, sector, site, pivot, offset, "resource", 500.0)
                emit("resource_node_defs", {"node_id": node, "sector_id": sector, "item_id": item, "capacity_units": 1000, "respawn_s": 1200.0})
                emit("resource_node_locations", {"node_id": node, "sector_id": sector, "anchor_id": point, "required_unlock_id": "unlock_open_routes"})
                emit("resource_grade_defs", {"node_id": node, "grade_level": 1 if choice == "safe" else 3, "display_name": "临时外围矿脉" if choice == "safe" else "临时核心矿脉", "yield_multiplier_bp": bp})
                emit("exploration_resource_defs", {"node_id": node, "event_id": event, "choice_id": choice})
    for key, name, perk, multiplier, description in (
        ("exp_scan", "遗迹扫描专精", "scan", 1.15, "调查与遗迹取证效率提高15%。"),
        ("exp_shielding", "环境防护协议", "mitigation", 0.75, "局部恒星环境热伤害降低25%。"),
        ("exp_mining", "临时矿脉校准", "mining", 1.1, "临时矿带采集产量提高10%，仍受舱位、配额与矿量限制。"),
    ):
        emit("unlock_defs", {"unlock_id": key + "_unlock", "display_name": name, "initially_unlocked": 0})
        emit("exploration_research_defs", {"research_id": key, "display_name": name, "required_insight": 20,
             "required_credit": 2000, "reward_unlock_id": key + "_unlock", "perk_kind": perk, "multiplier": multiplier, "description": description})
    sql.append("UPDATE catalog_meta SET schema_version=10,content_version='v0.11-exploration',ruleset_version='singleplayer_exploration_v1',source_document='doc/53-多阶段探索与环境风险.md';")
    (ROOT / "code/database/exploration_seed.sql").write_text("\n".join(sql) + "\n", encoding="utf-8", newline="\n")
    db.close()
    print("EXPLORATION_CONTENT six AU structures, eighteen variants, managed actors/resources, physical cover and research")


if __name__ == "__main__":
    main()
