"""Independent checks for the finite complete offline content scope and worst-case economics."""
from pathlib import Path
import sqlite3
import unittest
from decimal import Decimal as D
from test_balance import Catalog
ROOT=Path(__file__).resolve().parents[2]
class FullSingleplayerContentTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.db=sqlite3.connect(f'file:{ROOT / "code/data/catalog.db"}?mode=ro',uri=True);cls.db.row_factory=sqlite3.Row;cls.balance=Catalog()
 @classmethod
 def tearDownClass(cls):cls.db.close();cls.balance.connection.close()
 def rows(self,t):return [dict(r) for r in self.db.execute('SELECT * FROM '+t)]
 def test_full_finite_scope(self):
  self.assertEqual(len(self.rows('system_defs')),54);self.assertEqual(len(self.rows('ship_defs')),18);self.assertEqual(len(self.rows('module_defs')),42)
  self.assertEqual(len(self.rows('hull_recipe_defs')),18);self.assertEqual(len(self.rows('research_defs')),13);self.assertEqual(len(self.rows('base_module_defs')),4)
  self.assertEqual(len(self.rows('mission_defs')),52)
 def test_class_roles_and_different_budgets(self):
  roles={r['class_id'] for r in self.rows('ship_role_defs')};self.assertEqual(len(roles),9)
  ships={r['ship_id']:r for r in self.rows('ship_defs')}
  self.assertLess(ships['battleship_bastion']['turn_rad_s'],ships['frigate_kestrel']['turn_rad_s'])
  self.assertGreater(ships['transport_caravan']['cargo_l'],ships['battleship_bastion']['cargo_l'])
  self.assertGreater(ships['support_weaver']['recharge_eu_s'],ships['cruiser_horizon']['recharge_eu_s'])
 def test_tech_families_have_all_three_generations(self):
  families={}
  for r in self.rows('module_tech_defs'):
   if r['module_id'].startswith('module_spec_'):continue
   families.setdefault(r['module_id'].rsplit('_',1)[0],set()).add(r['tech_level'])
  self.assertEqual(len(families),13);self.assertTrue(all(x=={1,2,3} for x in families.values()))
  self.assertEqual({r['module_id'] for r in self.rows('module_salvage_recipe_defs')},{r['module_id'] for r in self.rows('module_defs')})
 def test_fixed_network_connects_all_systems_without_optional_hole(self):
  links=self.rows('connection_defs');fixed=[r for r in links if r['gate_class_id']!='gate_wandering_candidate'];self.assertEqual(len(fixed),72)
  reached={'sector_anchor'}
  while True:
   old=set(reached)
   for r in fixed:
    if r['origin_sector_id'] in reached:reached.add(r['target_sector_id'])
    if r['bidirectional'] and r['target_sector_id'] in reached:reached.add(r['origin_sector_id'])
   if reached==old:break
  self.assertEqual(reached,{r['sector_id'] for r in self.rows('sector_defs')})
 def test_battleship_shipyards_have_full_load_heavy_exit(self):
  ships={r['ship_id']:r for r in self.rows('ship_defs')};ports={r['station_id']:r for r in self.rows('station_defs')};gates={r['gate_class_id']:r for r in self.rows('gate_class_defs')}
  for stock in self.rows('station_ship_stock_defs'):
   if stock['ship_id']!='battleship_bastion':continue
   sh=ships[stock['ship_id']];bound=sh['dry_mass_kg']+sh['max_installed_mass_kg']+sh['max_payload_mass_kg'];sector=ports[stock['station_id']]['sector_id']
   self.assertTrue(any(sector in (r['origin_sector_id'],r['target_sector_id']) and gates[r['gate_class_id']]['max_gross_mass_kg']>=bound for r in self.rows('connection_defs')))
 def test_rare_resources_have_procurement_alternatives(self):
  required={r['item_id'] for r in self.rows('research_inputs')}|{r['item_id'] for r in self.rows('recipe_inputs')}
  stocked={r['item_id'] for r in self.rows('station_stock_defs') if r['station_id']=='station_anchor_port' and r['allow_buy'] and r['target_units']>0}
  self.assertTrue(required<=stocked)
  self.assertTrue(all(r['required_unlock_id'].startswith('unlock_site_') for r in self.rows('resource_node_locations') if r['node_id'].endswith('_special') and r['node_id']!='node_anchor_special'))
 def test_story_research_and_anomaly_unlock_dependencies(self):
  completed={'tutorial_exploration'};unlocks={r['unlock_id'] for r in self.rows('unlock_defs') if r['initially_unlocked']}|{'unlock_open_routes'}
  story={r['mission_id']:r for r in self.rows('mission_defs') if r['mission_kind']=='story'}
  while True:
   old=set(completed)
   for mid,r in story.items():
    req={x['prerequisite_mission_id'] for x in self.rows('mission_prerequisites') if x['mission_id']==mid}
    if req<=completed and r['required_unlock_id'] in unlocks:completed.add(mid)
   if completed==old:break
  self.assertTrue(set(story)<=completed)
  for research in self.rows('research_defs'):self.assertIn(research['verification_mission_id'],completed)
  reward_ids={r['unlock_id'] for r in self.rows('signal_unlock_rewards')};self.assertIn('unlock_wandering_mirror_mist',reward_ids)
 def test_all_hulls_cost_more_than_maximum_npc_buyback_with_best_facility(self):
  potential=self.balance.potentials();_,sell=self.balance.trade_coefficients();factor=max(D(r['effect_multiplier']) for r in self.rows('base_module_defs') if r['service_kind']=='industry')
  ships={r['ship_id']:r for r in self.rows('ship_defs')}
  for recipe in self.rows('hull_recipe_defs'):
   minimum=D(recipe['service_fee_credit'])/factor+sum(potential[r['item_id']]*r['quantity'] for r in self.rows('hull_recipe_inputs') if r['hull_recipe_id']==recipe['hull_recipe_id'])
   self.assertGreater(minimum,D(ships[recipe['ship_id']]['base_bid_credit'])*sell)
 def test_optional_hole_has_finite_budget_and_lifetime(self):
  holes=[r for r in self.rows('connection_defs') if r['gate_class_id']=='gate_wandering_candidate'];self.assertEqual(len(holes),1)
  definition=next(r for r in self.rows('gate_class_defs') if r['gate_class_id']=='gate_wandering_candidate')
  self.assertGreater(definition['total_mass_budget_kg'],definition['max_gross_mass_kg']);self.assertGreater(definition['lifetime_s'],0)
 def test_npc_levels_respect_region_ranges(self):
  risks={r['risk_zone_id']:r for r in self.rows('risk_zone_defs')};sectors={r['sector_id']:r for r in self.rows('sector_defs')};npcs={r['npc_id']:r for r in self.rows('npc_defs')}
  for spawn in self.rows('npc_spawn_defs'):
   n=npcs[spawn['npc_id']];risk=risks[sectors[spawn['sector_id']]['risk_zone_id']]
   self.assertGreaterEqual(n['level'],risk['npc_level_min']);self.assertLessEqual(n['level'],risk['npc_level_max'])
if __name__=='__main__':unittest.main(verbosity=2)
