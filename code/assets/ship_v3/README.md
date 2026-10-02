# 工业舰体独立表现资源

这套原创模型替换九类既有舰船和静默遗构敌舰的视觉模型。它保留 `assets/ships/*.tscn` 的原始字节，碰撞包围、相机标记、武器与工作挂点、推进器挂点继续由原 wrapper 定义；不产生新的玩法类别或数值。

运行适配器为 `runtime/visuals/industrial_visual_factory.gd`：载入既有 wrapper，只替换 `VisualRoot/Model`，并沿用其 transform。`XJSurfaceStyle.apply_ship` 根据 `v3_` 材质名称套用本包的空间 PBR shader，玻璃、微型窗列、警示涂装与喷口保持独立材质。钢材粗糙度限制为 0.65–0.90；纹理是低幅对象空间调制，不改变顶点、碰撞或命中。

造型使用有负空间的动力接合、独立装甲片及真实凹缝、偏轴功能舱、热交换器、结构筋肋、舱口和有人尺度的小窗。航路议会采用较规整的偏轴压力舱，深铸联合体使用粗重机械和分段装甲，游弋同盟使用可拆卸枪舱/货架，静默遗构使用裂体无人机械和低发光陶瓷。

Blender 可编辑源在 `source/`（不导入运行时），生成脚本在 `jiaoben/art/build_ships_v3.py`，可用固定 Blender 执行 `-- --all` 或 `-- --ship <ship_id>`。来源及所有运行文件摘要在本目录 `manifest.json`；外部微纹理的来源和身份由独立 `interface_v2/manifest.json` 管理。

EVE 官方文章仅参考暴露结构、装甲间隔、负空间及小窗表现尺度的设计讨论；本包不含其模型、贴图或专有舰名。本文不把无法打开的官方图片记录为已验真的截图。十类模型均由本项目脚本独立构造。

视觉验收用最终 PBR shader 在 Godot 原生渲染器中完成，几何与挂点测试入口为 `jiaoben/art/test_ship_v3.gd`。Godot导入已启用自动LOD，未制作手工LOD层级；实际大规模舰队的预算仍需另行测量，孤立预览不能作为整机帧率保证。
