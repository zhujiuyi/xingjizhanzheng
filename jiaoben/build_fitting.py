"""Append three equal-budget fire controls and eighteen factual role descriptions."""
from pathlib import Path
import sqlite3
from build_exploration_content import literal
ROOT=Path(__file__).resolve().parents[1]
def main():
 db=sqlite3.connect((ROOT/'code/data/catalog_operations_v14.db').as_uri()+'?mode=ro',uri=True);db.row_factory=sqlite3.Row
 assert db.execute('SELECT content_hash FROM catalog_meta').fetchone()[0]=='d46b84f07f8239e4a62cffe96e8467f44cc16553bf48fb46b9155e80869749b0'
 sql=['-- Append horizontal choices. All historical rows remain unchanged.']
 def emit(t,v):sql.append(f'INSERT INTO {t} ('+','.join(v)+') VALUES ('+','.join(literal(x) for x in v.values())+');')
 def clone(t,k,v):return dict(db.execute(f'SELECT * FROM {t} WHERE {k}=?',(v,)).fetchone())
 emit('fitting_analysis_defs',dict(singleton=1,burst_window_s=10.0,sustained_window_s=60.0,horizon_s=120.0,default_distance_m=1000.0))
 emit('specialization_balance_defs',dict(singleton=1,tactic_points=1,exploration_points=2,operation_points_per_unit=1,donation_item_id='material_structural_stock',donation_units_per_point=10,donation_credit_per_point=200,max_donation_points=20))
 emit('module_exclusion_groups',dict(group_id='spec_fire_control',max_installed=1))
 branches=[('burst','脉冲增压火控','短时爆发，代价是射程、电容与热量压力',1.30,.85,.80,1.50,1.70,1.0,1.0),('sustain','稳态馈能火控','降低电容和热量消耗，代价是峰值输出',.90,1.05,1.0,.65,.60,1.0,1.0),('range','远距校准火控','延长射程并提高弹速，代价是射界和输出',.85,1.10,1.40,1.15,1.10,1.20,.70)]
 for kind,title,description,damage,cycle,range_,energy,heat,speed,cone in branches:
  module='module_spec_'+kind;unlock='unlock_spec_'+kind;recipe='recipe_spec_'+kind
  unlocked=clone('unlock_defs','unlock_id','unlock_open_routes');unlocked.update(unlock_id=unlock,display_name=title+'设计',initially_unlocked=0);emit('unlock_defs',unlocked)
  item=clone('item_defs','item_id','module_engine_vector_i');item.update(item_id=module,display_name=title,unit_mass_kg=500.0,unit_volume_l=1500.0,base_ask_credit=9000,base_bid_credit=400);emit('item_defs',item)
  mod=clone('module_defs','module_id','module_engine_vector_i');mod.update(module_id=module,slot_type='utility',power_pu=8.0,cpu_cu=14.0,cycle_s=0.0,range_m=0.0,energy_eu=0.0,heat_hu=0.0,max_per_ship=1);emit('module_defs',mod)
  emit('module_group_members',dict(module_id=module,group_id='spec_fire_control'))
  emit('module_tech_defs',dict(module_id=module,faction_id='faction_neutral',tech_level=2,required_unlock_id=unlock))
  emit('weapon_tuning_defs',dict(module_id=module,specialization_kind=kind,damage_ratio=damage,cycle_ratio=cycle,range_ratio=range_,energy_ratio=energy,heat_ratio=heat,speed_ratio=speed,cone_ratio=cone))
  emit('specialization_research_defs',dict(research_id='spec_'+kind,display_name=title+'研究',module_id=module,required_points=10,credit_per_point=300,required_unlock_id='unlock_open_routes',reward_unlock_id=unlock))
  rec=clone('recipe_defs','recipe_id','recipe_engine_vector_i');rec.update(recipe_id=recipe,output_item_id=module,output_quantity=1,service_fee_credit=700);emit('recipe_defs',rec)
  emit('industry_recipe_defs',dict(blueprint_id=recipe,recipe_id=recipe,hull_recipe_id=None,duration_per_batch_s=24.0))
  for row in db.execute("SELECT * FROM recipe_inputs WHERE recipe_id='recipe_engine_vector_i'"):
   row=dict(row);row['recipe_id']=recipe;emit('recipe_inputs',row)
  emit('module_salvage_recipe_defs',dict(module_id=module,recipe_id=recipe))
  for row in db.execute("SELECT * FROM recycle_outputs WHERE source_item_id='module_engine_vector_i'"):
   row=dict(row);row['source_item_id']=module;emit('recycle_outputs',row)
  for (station,) in db.execute("SELECT station_id FROM station_service_defs WHERE service_id='manufacture'"):
   emit('recipe_access_defs',dict(recipe_id=recipe,station_id=station,required_unlock_id=unlock))
   stock=clone('station_stock_defs','item_id','module_engine_vector_i');stock.update(station_id=station,item_id=module,required_unlock_id=unlock,initial_units=3,target_units=3,hard_cap_units=6,restock_units_per_refresh=1,buyback_units_per_refresh=3);emit('station_stock_defs',stock)
 roles={
 'shuttle':('低成本轻航','船体便宜，灵活通行','武器与载荷预算有限','教学、近域调查、单批突破'),
 'frigate':('轻型巡护','机动与轻武器结合','防护和重武器尺寸受限','截击反制、近域护送'),
 'miner':('矿业平台','大矿舱和采集设备挂点','战斗火力与脱离能力需要保护','矿带、工业补给'),
 'destroyer':('火力护航','中型火力与护航速度','载荷和耐久低于巡洋舰','击破支援、无人机拦截'),
 'cruiser':('多用途主力','武器、防护、载荷综合预算','各项极限低于专用平台','拆除、突破、长航任务'),
 'battleship':('重型阵地火力','重武器挂载与防护容量','速度、转向和通行质量代价明显','阵地攻坚、舰队火力'),
 'transport':('大宗物流','大型货舱和共享载荷','武器与机动不是主项','区域需求、多批物资交付'),
 'support':('作业支援平台','通用与作业预算充足','武器挂载低于同级战斗舰','扫描、救援、无人机管理'),
 }
 for r in db.execute('SELECT ship_id,class_id,faction_id FROM ship_role_defs'):
  role,strength,cost,targets=roles['frigate' if r['class_id']=='combat_frigate' else r['class_id']] if r['class_id']!='explorer' else ('轻型探索','扫描与机动结合','防护和重武器尺寸受限','线索调查、遗迹取证、轻量物流')
  faction=r['faction_id']
  if r['ship_id'].find('_council_')>=0:strength+='；文明偏护盾、能量与无人机';cost+='；采购与制造受当前效忠限制'
  elif r['ship_id'].find('_forge_')>=0:strength+='；文明偏装甲与动能';cost+='；采购与制造受当前效忠限制'
  elif r['ship_id'].find('_roaming_')>=0:strength+='；文明偏机动与导弹';cost+='；采购与制造受当前效忠限制'
  emit('ship_role_guidance_defs',dict(ship_id=r['ship_id'],role_name=role,strength_text=strength,tradeoff_text=cost,recommended_targets=targets))
 sql.append("UPDATE catalog_meta SET schema_version=14,content_version='v0.15-fitting',ruleset_version='singleplayer_fitting_v1',source_document='doc/57-配装比较与火控专精.md';")
 (ROOT/'code/database/fitting_seed.sql').write_text('\n'.join(sql)+'\n',encoding='utf-8',newline='\n');db.close()
if __name__=='__main__':main()
