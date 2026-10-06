# 正式进度数据库结构

本目录提供单人客户端的固定受审SQL，运行路径为 `user://database/progress.db`。世界状态按关系表保存，数值来自封存的catalog完整副本。当前进度格式5，共131表、365触发器、32组状态；Godot原生数据服务与验证见 [24](../../../doc/24-数据服务实现与验证.md)。

| 文件 | 用途 |
| --- | --- |
| [001_core.sql](001_core.sql) | 版本、完整兼容身份、世界/会话/快照/槽及31组状态 |
| [002_frozen_catalog.sql](002_frozen_catalog.sql) | 73个内容定义表的复合键副本与不可变保护 |
| [003_seal_validation.sql](003_seal_validation.sql) | 完整快照封存前的必要记录、范围与形态校验 |
| [004_immutability.sql](004_immutability.sql) | 已封存状态和内容manifest的不可变保护 |
| [catalog_adapter_v0_3.sql](catalog_adapter_v0_3.sql) | 独立验证旧冻结内容的固定表/4视图适配器 |
| [005_singleplayer_expansion.sql](005_singleplayer_expansion.sql) | 格式2：新增高级内容定义与基地状态，保留旧冻结内容 |
| [006_signal_and_gate_lifetime.sql](006_signal_and_gate_lifetime.sql) | 格式3：异常解锁奖励与游离虫洞剩余寿命 |
| [007_profile_resume.sql](007_profile_resume.sql) | 格式4：独立记录菜单当前世界，跨世界继续可恢复 |
| [008_paid_engine_family.sql](008_paid_engine_family.sql) | 格式5：受审engine组的所有型号保存付费周期 |
| [catalog_adapter_v0_4.sql](catalog_adapter_v0_4.sql) | 83内容表版本的固定适配器 |
| [catalog_adapter_v0_4_r2.sql](catalog_adapter_v0_4_r2.sql) | 当前84内容表/4视图的固定适配器 |

加载迁移前启用foreign_keys；空库按编号执行八份迁移，同一 `BEGIN IMMEDIATE` 内登记SQL摘要。旧库先核对身份、历史数量和每份SQL摘要，再做已验证备份；所有待执行迁移在同一事务完成。错误保留旧库，不能删旧档绕过。正式运行只执行这些发布SQL与绑定参数，不执行保存的manifest文本。派生视图文本参与兼容核验，适配器属于受审代码。

完整保存/加载、动作去重、跨区端点、保留、备份与迁移顺序见 [18-进度数据库与存档实现规格](../../../doc/18-进度数据库与存档实现规格.md)。生成器、测试及夹具均在脚本目录：

```sh
# 从工作区根目录执行；测试与夹具只写内存及jiaoben/tmp。
/usr/local/bin/python3.14 jiaoben/tests/test_progress_schema.py
/usr/local/bin/python3.14 jiaoben/tests/store_run.py
/usr/local/bin/python3.14 jiaoben/progress_fixture.py --output jiaoben/tmp/progress-current-fixture.db
```

已登记的迁移字节不可覆盖重生成。`jiaoben/generate_frozen_schema.py` 保留历史生成方法，当前内容下拒绝改写002；后续增量生成入口是 `jiaoben/tests/store_generate_v4.py`、`store_generate_r2.py`，只在新结构审阅时使用，不能重写用户已执行过的迁移。

相同content_hash仅在规则代码、资产版本与canonical清单摘要、固定适配器版本也完全相同时复用。资产逻辑摘要遵循20，逐资源文件摘要单独验证。当前原生存读档证据不等同于所有玩法或Windows运行验收；独立客户端结果见24及26。

v0.15.0新增011，当前格式8共11份迁移，v0.7受审适配器冻结96表。空间实体身份在spatial_state，局部xyz不复制；新内容要求船/NPC/残骸完整地点绑定、NPC与出生地点一致、停靠船与站一致、封印后不可变。新规则的敌意AI保存屏障限于当前驾驶船所在地点，旧冻结世界保留既有屏障。升级先完整备份，再创建新版空间分支；旧手动档和冻结定义不改。详见[46](../../../doc/46-星系尺度与跃迁体验.md)。
