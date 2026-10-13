# 游戏代码

本目录存放《星际战舰》的游戏源码、正式模型与音频、运行配置和数据库。技术栈为 Godot 4 + typed GDScript + Forward+ + Blender + SQLite，锁定依赖见 [toolchain.lock.toml](toolchain.lock.toml)。

[project.godot](project.godot) 的实际启动场景是 [main.tscn](scenes/main.tscn)，由 [main.gd](runtime/main.gd) 协调权威模拟、3D场景、存读档和界面。当前定义包含54星系、18型舰船、I/II/III装备、三文明入籍与爵位、NPC舰队战争、教学与区域任务、科研、工业、设施和贸易；范围见[49](../doc/49-文明声望与星域战争.md)，实际验证状态见[26](../doc/26-开发阶段与交付记录.md)。

存档、读档和游戏数值以数据库为权威来源。基础定义来自[catalog_schema.sql](database/catalog_schema.sql)、[catalog_seed.sql](database/catalog_seed.sql)，再叠加空间、文明、工业、资源情报、探索、迁移矿带、战术、行动、火控、舰种能力、文明考核、雇佣支援、[状态与情报](database/situational_schema.sql)、[边疆](database/frontier_schema.sql)和[行军与成长](database/march_schema.sql)定义。当前源码内容`v0.24-march`、目录schema23、176定义表，正式[catalog.db](data/catalog.db)由[build_catalog.py](../jiaoben/build_catalog.py)重建并只读加载。进度格式26追加029行军、成长及贡献奖励收据，保存114组typed状态；各历史目录作为受审升级桥保留，最近为[catalog_fleet_v23.db](data/catalog_fleet_v23.db)。配装比较、横向研究、太空HUD和舰种能力见[57](../doc/57-配装比较与火控专精.md)、[58](../doc/58-太空界面与简洁配装分析.md)、[59](../doc/59-舰种能力与有限承运.md)、[60](../doc/60-文明贡献与指挥资格.md)、[61](../doc/61-边疆战争与重建争夺.md)、[62](../doc/62-雇佣支援与舰队指令.md)。自有舰队、船员与辅助无人机已在v0.31正式Windows包交付；v0.32源码包含跨星系行军及成长导航，正式交付状态以[26](../doc/26-开发阶段与交付记录.md)为准。修改数值须更新SQL并执行内容、数值及存档检查。

个人进度保存在应用 `user://database/progress.db`，完整快照和冻结内容使用规范化SQLite表，不提交Git。原生服务实现与兼容验证见 [24](../doc/24-数据服务实现与验证.md)；受审迁移见 [progress](database/progress/README.md)。类型化数据和预留联机协议见 [contracts](contracts/README.md)。

正式美术资源的尺寸、碰撞、挂点、来源及摘要见 [25](../doc/25-美术资源与视觉实现.md)。Blender源文件在 `assets/source/`，发行包只带运行资源；`assets/manifest.json` 校验逐资源原始字节。`addons/xj-asset-export/` 是确保导出后仍能校验原始资源的正式编辑器插件。

辅助构建、测试和中间产物在 `../jiaoben/`；正式客户端构建配置为 [export_presets.cfg](export_presets.cfg)。构建和本机缓存加入Git忽略，不能将生成包代替源码提交。
