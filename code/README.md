# 游戏代码

本目录存放《星际战舰》的游戏源码、正式模型与音频、运行配置和数据库。技术栈为 Godot 4 + typed GDScript + Forward+ + Blender + SQLite，锁定依赖见 [toolchain.lock.toml](toolchain.lock.toml)。

[project.godot](project.godot) 的实际启动场景是 [main.tscn](scenes/main.tscn)，由 [main.gd](runtime/main.gd) 协调权威模拟、3D场景、存读档和界面。完整单人版定义包含十星系、九类舰、I/II/III装备、教学与区域任务、科研、工业、个人设施与贸易；功能范围及实际验证状态见 [23](../doc/23-完整单人版交付范围与实现清单.md) 与 [26](../doc/26-开发阶段与交付记录.md)。

存档、读档和游戏数值以数据库为权威来源。数值定义来自 [catalog_schema.sql](database/catalog_schema.sql) 和 [catalog_seed.sql](database/catalog_seed.sql)，当前内容版本为 `v0.5-integrity`；正式 [catalog.db](data/catalog.db) 由 [build_catalog.py](../jiaoben/build_catalog.py) 重建，以只读方式加载。修改数值须更新SQL并执行相关内容、数值和存档检查。

个人进度保存在应用 `user://database/progress.db`，完整快照和冻结内容使用规范化SQLite表，不提交Git。原生服务实现与兼容验证见 [24](../doc/24-数据服务实现与验证.md)；受审迁移见 [progress](database/progress/README.md)。类型化数据和预留联机协议见 [contracts](contracts/README.md)。

正式美术资源的尺寸、碰撞、挂点、来源及摘要见 [25](../doc/25-美术资源与视觉实现.md)。Blender源文件在 `assets/source/`，发行包只带运行资源；`assets/manifest.json` 校验逐资源原始字节。`addons/xj-asset-export/` 是确保导出后仍能校验原始资源的正式编辑器插件。

辅助构建、测试和中间产物在 `../jiaoben/`；正式客户端构建配置为 [export_presets.cfg](export_presets.cfg)。构建和本机缓存加入Git忽略，不能将生成包代替源码提交。
