# 正式进度数据库结构

本目录提供首版单人闭环的固定受审SQL，运行路径为 `user://database/progress.db`。世界状态按关系表保存，数值来自封存的catalog完整副本。当前是进度格式1，空库初始化不代表Godot SaveService已实现。

| 文件 | 用途 |
| --- | --- |
| [001_core.sql](001_core.sql) | 版本、完整兼容身份、世界/会话/快照/槽及31组状态 |
| [002_frozen_catalog.sql](002_frozen_catalog.sql) | 73个内容定义表的复合键副本与不可变保护 |
| [003_seal_validation.sql](003_seal_validation.sql) | 完整快照封存前的必要记录、范围与形态校验 |
| [004_immutability.sql](004_immutability.sql) | 已封存状态和内容manifest的不可变保护 |
| [catalog_adapter_v0_3.sql](catalog_adapter_v0_3.sql) | 独立验证旧冻结内容的固定表/4视图适配器 |

加载迁移前启用foreign_keys；四份迁移在同一 `BEGIN IMMEDIATE` 内按编号执行并登记SQL摘要。正式运行只能执行这些随工程发布的SQL与绑定参数，不执行保存的manifest文本。派生视图文本作为兼容身份核验，适配器属于受审代码。

完整保存/加载、动作去重、跨区端点、保留、备份与迁移顺序见 [18-进度数据库与存档实现规格](../../../doc/18-进度数据库与存档实现规格.md)。生成器、测试及夹具均在脚本目录：

```sh
# 从工作区根目录执行；测试与夹具只写内存及jiaoben/tmp。
/usr/local/bin/python3.14 jiaoben/tests/test_progress_schema.py
/usr/local/bin/python3.14 jiaoben/progress_fixture.py --output jiaoben/tmp/progress-devready-fixture.db
# 仅catalog结构变更后生成、审阅并按正式迁移规则处理。
/usr/local/bin/python3.14 jiaoben/generate_frozen_schema.py
```

相同content_hash仅在规则代码、资产版本与逻辑清单摘要、固定适配器版本也完全相同时复用。资产逻辑摘要遵循20的canonical JSON规则；逐资源文件摘要单独验证。测试通过证明SQLite参考结构与事务边界，不代表游戏存读档或Windows客户端验收完成。
