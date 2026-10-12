"""Author finite crew and owned-hull bindings; emitted SQL is the authority."""
from pathlib import Path
import sqlite3
import math

ROOT = Path(__file__).resolve().parents[1]


def literal(value):
    if value is None:
        return "NULL"
    if isinstance(value, str):
        return "'" + value.replace("'", "''") + "'"
    return str(value)


def main():
    source = ROOT / "code/data/catalog_scenarios_v22.db"
    with sqlite3.connect(source.as_uri() + "?mode=ro", uri=True) as db:
        db.row_factory = sqlite3.Row
        sql = ["-- Owned ships retain their actual equipment, resources and damage."]

        def insert(table, values):
            sql.append("INSERT INTO " + table + " VALUES(" + ",".join(map(literal, values)) + ");")

        insert("fleet_balance_defs", [1, 2, 8, "unlock_open_routes", 12000.0, 600.0, 1600.0,
               1800.0, 6.0, 120.0, 100, 50, 600.0, 60, 2, 8, 10, 20, 3,
               1200.0, 300, 300.0, 150, 1000, 128])
        professions = [
            ("pilot", "操舰员", 600, 60, "turn_rad_s", "ratio", "distance", 1000.0,
             "提高实际转向效率；真实局部航行积累经验。", ("林岚", "周朔")),
            ("gunner", "火控员", 800, 80, "cooling_hu_s", "ratio", "damage", 100.0,
             "提高散热效率；有效武器命中积累经验。", ("时雨", "宋衡")),
            ("engineer", "工程师", 900, 90, "remote_repair_multiplier", "ratio", "repair", 50.0,
             "提高有效远程维修；实际修复损伤积累经验。", ("何筝", "许钧")),
            ("scout", "侦察员", 700, 70, "scan_strength", "flat", "survey", 0.1,
             "提高实际扫描强度；完成调查积累经验。", ("沈砚", "鹿遥")),
        ]
        for duty, title, fee, salary, stat, mode, contribution, unit, description, names in professions:
            profession = "crew_" + duty
            insert("crew_profession_defs", [profession, title, duty, fee, salary, stat, mode,
                   contribution, unit, description])
            for rank, experience, multiplier in [(1, 0, 1.0), (2, 100, 1.25), (3, 300, 1.5)]:
                insert("crew_rank_defs", [profession, rank, experience,
                       rank * (5.0 if mode == "flat" else 0.04), multiplier])
            for index, name in enumerate(names, 1):
                insert("crew_profile_defs", [profession + "_" + str(index), name, profession])

        station = db.execute("SELECT * FROM station_defs WHERE station_id='station_anchor_port'").fetchone()
        origin = db.execute("SELECT * FROM anchor_defs WHERE anchor_id=?", (station["undock_anchor_id"],)).fetchone()
        site = db.execute("SELECT site_id FROM anchor_site_defs WHERE anchor_id=?", (origin["anchor_id"],)).fetchone()[0]
        zone = db.execute("SELECT risk_zone_id FROM sector_defs WHERE sector_id=?", (station["sector_id"],)).fetchone()[0]
        behavior_base = dict(db.execute("SELECT * FROM npc_behavior_defs WHERE behavior_id='behavior_scout'").fetchone())
        for hull in db.execute("SELECT * FROM ship_defs ORDER BY ship_id"):
            identity = "owned_" + hull["ship_id"]
            # Archetype data supplies geometry/fallback limits. FleetPilot must
            # fire only real installed weapons, never this descriptor's DPS.
            insert("npc_archetype_defs", [identity, "自有 · " + hull["display_name"],
                   int(hull["shield_max"]), int(hull["armor_max"]), int(hull["hull_max"]),
                   1.0, "kinetic", hull["max_speed_mps"], 1000.0, 0])
            for row in db.execute("SELECT layer_id,damage_type,resistance FROM ship_resistances WHERE ship_id=?", (hull["ship_id"],)):
                insert("npc_resistances", [identity, *row])
            behavior = dict(behavior_base)
            behavior.update(behavior_id=identity + "_behavior", archetype_id=identity,
                            detection_range_m=6000.0, target_drop_range_m=12000.0,
                            leash_radius_m=1000.0,
                            return_radius_m=60.0, acceleration_mps2=hull["acceleration_mps2"],
                            turn_rad_s=hull["turn_rad_s"])
            insert("npc_behavior_defs", list(behavior.values()))
            insert("npc_defs", [identity + "_npc", identity, 1, zone])
            for suffix, kind, x in [("_anchor", "npc_spawn", 600.0), ("_patrol", "patrol", 660.0)]:
                insert("anchor_defs", [identity + suffix, station["sector_id"], kind,
                       origin["x_m"] + x, origin["y_m"], origin["z_m"] + 4000.0,
                       origin["yaw_rad"], 60.0, 0.0])
                insert("anchor_site_defs", [identity + suffix, site])
            spawn = identity + "_spawn"
            insert("npc_spawn_defs", [spawn, identity + "_npc", station["sector_id"],
                   identity + "_anchor", identity + "_behavior", "mission_scoped",
                   "unlock_open_routes", None, 0, 0])
            insert("npc_patrol_points", [spawn, 0, identity + "_patrol"])
            crew_slots = 3 if hull["dry_mass_kg"] >= 1000000 else 2
            insert("fleet_hull_defs", [hull["ship_id"], spawn, crew_slots])
        for role, ships in {
            "repair": ["support_weaver", "support_council_choir", "cruiser_horizon", "cruiser_council_sentinel"],
            "recon": ["frigate_lantern", "cruiser_horizon", "cruiser_roaming_kite", "support_council_choir"],
        }.items():
            for ship in ships:
                insert("ship_auxiliary_permissions", [ship, role, 1])
        recycle_ratio = db.execute("SELECT value_real FROM rule_parameters WHERE parameter_id='recycle_input_return_ratio'").fetchone()[0]
        stations = [row[0] for row in db.execute("SELECT station_id FROM station_service_defs WHERE service_id='manufacture'")]
        if not stations:
            raise ValueError("Auxiliary bays require real manufacturing stations")
        for role in ["repair", "recon"]:
            for tier, suffix in [(1, "i"), (2, "ii")]:
                module = "module_aux_" + role + "_" + suffix
                recipe = "recipe_aux_" + role + "_" + suffix
                title = ("缝翼维修机库" if role == "repair" else "远瞳侦察机库") + (" I" if tier == 1 else " II")
                price = (9000 if role == "repair" else 8000) if tier == 1 else (22000 if role == "repair" else 20000)
                unlock = "unlock_exploration_equipment" if tier == 1 else "unlock_tech_ii"
                insert("item_defs", [module, title, "module", 1800.0 * tier, 2200 * tier, 0, price, price // 4])
                control_range = (3000.0 if tier == 1 else 4500.0) if role == "repair" else (8000.0 if tier == 1 else 12000.0)
                insert("module_defs", [module, "work", 55.0 * tier, 55.0 + 35.0 * (tier-1),
                       12.0, control_range, 24.0 + 12.0 * (tier-1), 12.0 + 8.0 * (tier-1), 1])
                insert("module_tech_defs", [module, "faction_neutral", tier, unlock])
                insert("module_activation_priority", [module, 20 if role == "repair" else 10])
                insert("auxiliary_drone_defs", [module, role, 2 if tier == 1 else 3,
                       (650.0 + 150.0 * (tier-1)) if role == "repair" else (900.0 + 300.0 * (tier-1)), 350.0 + 100.0 * (tier-1), 3.0, 100.0,
                       30.0 if role == "repair" else 40.0, 32.0, 70.0 + 25.0 * (tier-1), (20.0 + 4.0 * (tier-1)) if role == "repair" else 0.0,
                       (2500.0 + 1500.0 * (tier-1)) if role == "recon" else 0.0, 120.0,
                       "repair_kit_i" if role == "repair" else None, 1 if role == "repair" else 0,
                       "material_structural_stock", 2 * tier, 180 * tier])
                inputs = {"component_power_cell": 2 * tier, "component_thruster_cluster": tier,
                          "component_sensor_core": 2 * tier, "material_feather_alloy": 4 * tier}
                inputs["component_repair_mesh" if role == "repair" else "component_scan_frame"] = 3 * tier
                insert("recipe_defs", [recipe, module, 1, 600 * tier, 0.0])
                insert("industry_recipe_defs", [recipe, recipe, None, 24.0 * tier])
                insert("module_salvage_recipe_defs", [module, recipe])
                for item, quantity in inputs.items():
                    insert("recipe_inputs", [recipe, item, quantity])
                    returned = math.floor(quantity * recycle_ratio)
                    if returned:
                        insert("recycle_outputs", [module, item, returned])
                for station_id in stations:
                    insert("recipe_access_defs", [recipe, station_id, unlock])
                    insert("station_stock_defs", [station_id, module, unlock, 2, 2, 4, 1, 2, 1, 1])
        sql.append("UPDATE catalog_meta SET schema_version=22,content_version='v0.23-fleet',"
                   "ruleset_version='singleplayer_fleet_v1',source_document='doc/66-自有舰队船员与辅助无人机.md';")
        (ROOT / "code/database/fleet_seed.sql").write_text("\n".join(sql) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
