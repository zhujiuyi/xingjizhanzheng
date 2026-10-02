# 游戏代码

本目录存放《星际战舰》的游戏源码、运行所需配置和资源。

技术栈为 Godot 4 + typed GDScript + Forward+ + Blender + SQLite。工程入口 [project.godot](project.godot) 为已通过导入的骨架，尚无可玩主场景。锁定依赖见 [toolchain.lock.toml](toolchain.lock.toml)。不要将测试、临时脚本或生成文档混入源码。

存档、读档和游戏数值以数据库为权威来源。数据库定义、迁移与正式种子数据随工程放在本目录；个人进度数据库放在应用的 `user://` 数据目录，不提交 Git。具体边界见 [数据库方案](../doc/10-数据库与存读档技术方案.md)。

开发环境说明见 [开发环境](../doc/02-开发环境.md)。

已建立的数值资产：

- [catalog_schema.sql](database/catalog_schema.sql)：首轮数值库结构与约束。
- [catalog_seed.sql](database/catalog_seed.sql)：`v0.3-devready` 的正式种子数据。
- [catalog.db](data/catalog.db)：由上述 SQL 生成的 SQLite 数值数据库，运行时以只读方式加载。

构建使用 [build_catalog.py](../jiaoben/build_catalog.py)，验证方法与实际覆盖见 [开发准备度](../doc/16-开发准备度与缺口清单.md)。修改数值先更新种子及内容版本，再构建、验证并同步设计表；不要直接改二进制数据库而失去可重建来源。

进度库正式 SQL 与冻结定义迁移见 [progress](database/progress/README.md)，纯类型接口见 [contracts](contracts/README.md)，四船占位见 [assets/placeholders](assets/placeholders/README.md)。SQLite 桌面扩展已随工程集成；其运行验证和双平台导出边界见 [工具链验证](../doc/22-工具链锁定与技术验证.md)。

这些提供编码输入；Godot SaveService、权威模拟、完整玩法场景和 UI 仍待实现。当前数据库覆盖首版两星系，不声称已经实现十星系及高级内容。
